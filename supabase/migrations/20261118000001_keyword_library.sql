-- =====================================================================================
-- Global SEO keyword library + per-branch keyword selection.
-- See docs/plans/02-keyword-library/00-README.md (decisions K1-K7).
-- Applying it DELETES every existing keyword row (the plan 01 per-subcategory seed) and
-- replaces it with the global library below. feedback_submissions.keywords snapshots
-- ({id,label} jsonb) are untouched.
-- =====================================================================================

-- ---------- 1. Customer RPCs reference keywords.subcategory_id; drop them first ----------
drop function public.get_feedback_form(text);
drop function public.submit_feedback(text, int, uuid[], text, text);

-- ---------- 2. Library schema (K1). Grants and policies on keywords stay as they are (K5) ----------
delete from public.keywords;

drop index public.keywords_subcategory_label_lower_key;
drop index public.keywords_subcategory_id_is_active_idx;
alter table public.keywords drop column subcategory_id; -- its foreign key goes with it

alter table public.keywords drop constraint keywords_label_check;
alter table public.keywords add constraint keywords_label_check check (char_length(label) between 1 and 60);

-- null = General (shown for every category)
alter table public.keywords add column category_id uuid references public.categories(id);
create unique index keywords_label_lower_key on public.keywords (lower(label));
create index keywords_category_id_is_active_idx on public.keywords (category_id, is_active);

-- ---------- 3. Seed (K2). Idempotent: unique (lower(label)) + on conflict do nothing ----------
insert into public.keywords (category_id, label, sort_order)
select null, v.label, v.ord
from (values
  ('friendly staff', 1),
  ('value for money', 2),
  ('clean and hygienic', 3),
  ('highly recommended', 4),
  ('great customer service', 5),
  ('quick service', 6),
  ('professional and courteous', 7),
  ('convenient location', 8),
  ('easy parking', 9),
  ('reasonable prices', 10),
  ('welcoming atmosphere', 11),
  ('will definitely come back', 12)
) v(label, ord)
on conflict do nothing;

insert into public.keywords (category_id, label, sort_order)
select c.id, v.label, v.ord
from (values
  ('Restaurants & Cafes', 'best coffee in town', 1),
  ('Restaurants & Cafes', 'family friendly restaurant', 2),
  ('Restaurants & Cafes', 'tasty food', 3),
  ('Restaurants & Cafes', 'cozy ambience', 4),
  ('Restaurants & Cafes', 'fresh ingredients', 5),
  ('Restaurants & Cafes', 'generous portions', 6),
  ('Restaurants & Cafes', 'great place for brunch', 7),
  ('Restaurants & Cafes', 'quick lunch spot', 8),

  ('Retail', 'wide range of products', 1),
  ('Retail', 'helpful sales staff', 2),
  ('Retail', 'latest collection', 3),
  ('Retail', 'easy returns and exchange', 4),
  ('Retail', 'great deals and discounts', 5),
  ('Retail', 'genuine products', 6),
  ('Retail', 'quick billing', 7),

  ('Healthcare', 'experienced doctors', 1),
  ('Healthcare', 'caring nursing staff', 2),
  ('Healthcare', 'minimal waiting time', 3),
  ('Healthcare', 'clean clinic', 4),
  ('Healthcare', 'clear diagnosis and treatment', 5),
  ('Healthcare', 'easy appointment booking', 6),
  ('Healthcare', 'affordable treatment', 7),

  ('Beauty & Wellness', 'best haircut in town', 1),
  ('Beauty & Wellness', 'skilled stylists', 2),
  ('Beauty & Wellness', 'relaxing spa experience', 3),
  ('Beauty & Wellness', 'premium beauty products', 4),
  ('Beauty & Wellness', 'hygienic salon', 5),
  ('Beauty & Wellness', 'bridal makeup', 6),
  ('Beauty & Wellness', 'expert skin care', 7),

  ('Hotels & Stays', 'comfortable rooms', 1),
  ('Hotels & Stays', 'delicious breakfast', 2),
  ('Hotels & Stays', 'helpful front desk staff', 3),
  ('Hotels & Stays', 'great location for sightseeing', 4),
  ('Hotels & Stays', 'spotless rooms', 5),
  ('Hotels & Stays', 'peaceful stay', 6),
  ('Hotels & Stays', 'excellent amenities', 7),

  ('Automotive', 'honest car service', 1),
  ('Automotive', 'quick vehicle servicing', 2),
  ('Automotive', 'transparent pricing', 3),
  ('Automotive', 'smooth car buying experience', 4),
  ('Automotive', 'knowledgeable service advisors', 5),
  ('Automotive', 'thorough car wash', 6),
  ('Automotive', 'timely delivery', 7),

  ('Education', 'experienced teachers', 1),
  ('Education', 'excellent study material', 2),
  ('Education', 'personal attention to students', 3),
  ('Education', 'great learning environment', 4),
  ('Education', 'good exam results', 5),
  ('Education', 'practical hands-on training', 6),
  ('Education', 'supportive faculty', 7),

  ('Fitness', 'well equipped gym', 1),
  ('Fitness', 'certified personal trainers', 2),
  ('Fitness', 'clean locker rooms', 3),
  ('Fitness', 'flexible class timings', 4),
  ('Fitness', 'motivating trainers', 5),
  ('Fitness', 'great yoga classes', 6),
  ('Fitness', 'affordable membership', 7)
) v(category, label, ord)
join public.categories c on lower(c.name) = lower(v.category)
on conflict do nothing;

-- ---------- 4. Branch selection (K3). Read via RLS; writes only through set_branch_keywords ----------
create table public.branch_keywords (
  branch_id uuid not null references public.branches(id),
  keyword_id uuid not null references public.keywords(id),
  position int not null check (position between 1 and 10),
  primary key (branch_id, keyword_id),
  unique (branch_id, position)
);
create index branch_keywords_keyword_id_idx on public.branch_keywords (keyword_id);

alter table public.branch_keywords enable row level security;
revoke all on public.branch_keywords from anon, authenticated;
grant select on public.branch_keywords to authenticated;

create policy branch_keywords_super on public.branch_keywords for select to authenticated
  using (public.current_app_role() = 'super_admin');
create policy branch_keywords_own on public.branch_keywords for select to authenticated
  using (public.current_app_role() = 'business_admin' and exists (
    select 1 from public.branches b
    where b.id = branch_keywords.branch_id and b.company_id = public.current_company_id()));

-- ---------- 5. Write RPC (K4) ----------
create function public.set_branch_keywords(p_branch_id uuid, p_keyword_ids uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_role text := public.current_app_role();
  v_company_id uuid;
  v_ids uuid[];
  v_bad int;
begin
  if v_role is null or v_role not in ('super_admin', 'business_admin') then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Lock the branch row so concurrent saves for the same branch run one after the other.
  select b.company_id into v_company_id from public.branches b where b.id = p_branch_id for update;
  if not found then raise exception 'unknown branch' using errcode = 'P0002'; end if;
  if v_role = 'business_admin' and v_company_id is distinct from public.current_company_id() then
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

  delete from public.branch_keywords where branch_id = p_branch_id;
  insert into public.branch_keywords (branch_id, keyword_id, position)
  select p_branch_id, u.id, u.pos
  from unnest(v_ids) with ordinality as u(id, pos);
end $$;

revoke all on function public.set_branch_keywords(uuid, uuid[]) from public;
grant execute on function public.set_branch_keywords(uuid, uuid[]) to authenticated;

-- ---------- 6. Customer RPCs (K6, K7). Anonymous callers only ever use these. ----------
-- Not found (null) when the branch, company, subcategory or category is inactive.
-- keywords = the branch's active picks in picked order (max 10); none picked = [].
create function public.get_feedback_form(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'branch_name', b.name,
    'company_name', c.name,
    'google_place_id', b.google_place_id,
    'category_name', k.name,
    'subcategory_name', s.name,
    'keywords', coalesce((
      select jsonb_agg(jsonb_build_object('id', w.id, 'label', w.label) order by bk.position)
      from public.branch_keywords bk
      join public.keywords w on w.id = bk.keyword_id and w.is_active
      where bk.branch_id = b.id
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

  -- Every id must be an active keyword picked for this branch.
  if (select count(*) from public.branch_keywords bk
      join public.keywords w on w.id = bk.keyword_id and w.is_active
      where bk.branch_id = v_branch.id and bk.keyword_id = any(v_ids))
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
