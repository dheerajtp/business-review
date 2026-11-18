-- =====================================================================================
-- Company-level keyword picks inherited by branches without their own picks.
-- See docs/plans/04-company-keywords/00-README.md (decisions M1-M6).
-- No data migration (M6): companies start with no company keywords; branches that already
-- have picks keep them as overrides. Runs after 20261119000001_prune_empty_categories.sql.
-- =====================================================================================

-- ---------- 1. Company selection (M1). Read via RLS; writes only through set_company_keywords ----------
create table public.company_keywords (
  company_id uuid not null references public.companies(id),
  keyword_id uuid not null references public.keywords(id),
  position int not null check (position between 1 and 10),
  primary key (company_id, keyword_id),
  unique (company_id, position)
);
create index company_keywords_keyword_id_idx on public.company_keywords (keyword_id);

alter table public.company_keywords enable row level security;
revoke all on public.company_keywords from anon, authenticated;
grant select on public.company_keywords to authenticated;

create policy company_keywords_super on public.company_keywords for select to authenticated
  using (public.current_app_role() = 'super_admin');
create policy company_keywords_own on public.company_keywords for select to authenticated
  using (public.current_app_role() = 'business_admin' and company_id = public.current_company_id());

-- ---------- 2. Write RPC (M2). Same rules as set_branch_keywords ----------
create function public.set_company_keywords(p_company_id uuid, p_keyword_ids uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_role text := public.current_app_role();
  v_ids uuid[];
  v_bad int;
begin
  if v_role is null or v_role not in ('super_admin', 'business_admin') then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Lock the company row so concurrent saves for the same company run one after the other.
  perform 1 from public.companies c where c.id = p_company_id for update;
  if not found then raise exception 'unknown company' using errcode = 'P0002'; end if;
  if v_role = 'business_admin' and p_company_id is distinct from public.current_company_id() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Distinct ids kept at their first position; count the ones that are not an active keyword
  -- (a null element never matches, so it counts as unknown).
  select coalesce(array_agg(x.id order by x.pos), '{}'), count(*) filter (where w.id is null)
    into v_ids, v_bad
  from (
    select u.id, min(u.pos) as pos
    from unnest(coalesce(p_keyword_ids, '{}'::uuid[])) with ordinality as u(id, pos)
    group by u.id
  ) x
  left join public.keywords w on w.id = x.id and w.is_active;

  if cardinality(v_ids) > 10 then
    raise exception 'too many keywords' using errcode = '22023';
  end if;
  if v_bad > 0 then
    raise exception 'unknown keyword' using errcode = '22023';
  end if;

  delete from public.company_keywords where company_id = p_company_id;
  insert into public.company_keywords (company_id, keyword_id, position)
  select p_company_id, u.id, u.pos
  from unnest(v_ids) with ordinality as u(id, pos);
end $$;

revoke all on function public.set_company_keywords(uuid, uuid[]) from public;
grant execute on function public.set_company_keywords(uuid, uuid[]) to authenticated;

-- ---------- 3. Resolution rule (M3). Internal: only the customer RPCs call it ----------
-- The branch's own picks if it has at least one row, otherwise its company's picks.
-- Archived keywords are not filtered here; callers join to active keywords.
create function public.effective_keyword_ids(p_branch_id uuid) returns table (keyword_id uuid, pos int)
language sql stable security definer set search_path = public as $$
  select bk.keyword_id, bk.position
  from public.branch_keywords bk
  where bk.branch_id = p_branch_id
  union all
  select ck.keyword_id, ck.position
  from public.branches b
  join public.company_keywords ck on ck.company_id = b.company_id
  where b.id = p_branch_id
    and not exists (select 1 from public.branch_keywords x where x.branch_id = p_branch_id)
$$;

revoke all on function public.effective_keyword_ids(uuid) from public;

-- ---------- 4. Customer RPCs (M4, M5). Only the keyword source changes ----------
drop function public.get_feedback_form(text);
drop function public.submit_feedback(text, int, uuid[], text, text);

-- Not found (null) when the branch, company, subcategory or category is inactive.
-- keywords = the branch's effective active keywords in position order (max 10); none = [].
create function public.get_feedback_form(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'branch_name', b.name,
    'company_name', c.name,
    'google_place_id', b.google_place_id,
    'category_name', k.name,
    'subcategory_name', s.name,
    'keywords', coalesce((
      select jsonb_agg(jsonb_build_object('id', w.id, 'label', w.label) order by e.pos)
      from public.effective_keyword_ids(b.id) e
      join public.keywords w on w.id = e.keyword_id and w.is_active
    ), '[]'::jsonb)
  )
  from public.branches b
  join public.companies c on c.id = b.company_id and c.is_active
  join public.subcategories s on s.id = c.subcategory_id and s.is_active
  join public.categories k on k.id = s.category_id and k.is_active
  where b.slug = p_slug and b.is_active
$$;

create function public.submit_feedback(
  p_slug text, p_rating int, p_keyword_ids uuid[], p_comment text, p_contact text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_branch public.branches%rowtype;
  v_ids uuid[];
  v_out jsonb;
  v_hash text;
  v_id uuid;
begin
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'invalid rating' using errcode = '22023';
  end if;
  p_comment := nullif(btrim(p_comment), '');
  p_contact := nullif(btrim(p_contact), '');
  if char_length(p_comment) > 2000 or char_length(p_contact) > 200 then
    raise exception 'text too long' using errcode = '22023';
  end if;

  -- Distinct ids, kept in the order the customer first picked them. A null element stays in
  -- the list and is rejected below as an unknown keyword.
  select coalesce(array_agg(x.id order by x.pos), '{}') into v_ids
  from (
    select u.id, min(u.pos) as pos
    from unnest(coalesce(p_keyword_ids, '{}'::uuid[])) with ordinality as u(id, pos)
    group by u.id
  ) x;
  if cardinality(v_ids) > 10 then
    raise exception 'too many keywords' using errcode = '22023';
  end if;

  select b.* into v_branch from public.branches b where b.slug = p_slug and b.is_active;
  if not found then raise exception 'unknown branch' using errcode = 'P0002'; end if;
  perform 1
    from public.companies c
    join public.subcategories s on s.id = c.subcategory_id and s.is_active
    join public.categories k on k.id = s.category_id and k.is_active
    where c.id = v_branch.company_id and c.is_active;
  if not found then raise exception 'unknown branch' using errcode = 'P0002'; end if;

  -- Flood control: 30 submissions / 10 min per branch per client address.
  v_hash := nullif(split_part(coalesce(
    current_setting('request.headers', true)::jsonb ->> 'x-forwarded-for', ''), ',', 1), '');
  if v_hash is not null then
    v_hash := md5(v_hash);
    if (select count(*) from public.feedback_submissions
        where branch_id = v_branch.id and client_hash = v_hash
          and created_at > now() - interval '10 minutes') >= 30 then
      raise exception 'too many submissions' using errcode = '54000';
    end if;
  end if;

  -- Every id must be an active keyword in the branch's effective set.
  if (select count(*) from public.effective_keyword_ids(v_branch.id) e
      join public.keywords w on w.id = e.keyword_id and w.is_active
      where e.keyword_id = any(v_ids))
     <> cardinality(v_ids) then
    raise exception 'unknown keyword' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id', w.id, 'label', w.label) order by u.pos), '[]'::jsonb)
    into v_out
    from unnest(v_ids) with ordinality as u(id, pos)
    join public.keywords w on w.id = u.id;

  insert into public.feedback_submissions
    (branch_id, company_id, rating, keywords, comment, contact, client_hash)
  values (v_branch.id, v_branch.company_id, p_rating, v_out, p_comment, p_contact, v_hash)
  returning id into v_id;
  return v_id;
end $$;

revoke all on function public.get_feedback_form(text), public.submit_feedback(text, int, uuid[], text, text) from public;
grant execute on function public.get_feedback_form(text), public.submit_feedback(text, int, uuid[], text, text)
  to anon, authenticated;
