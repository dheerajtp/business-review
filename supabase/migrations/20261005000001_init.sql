-- Fairobuy v1 schema. See SPEC.md. RLS is the authorization boundary;
-- anonymous customers only ever touch the three RPCs at the bottom.

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  description text check (char_length(description) <= 500),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  category_id uuid not null references public.categories(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  name text not null check (char_length(name) between 1 and 120),
  slug text not null unique default substr(replace(gen_random_uuid()::text, '-', ''), 1, 12),
  google_place_id text not null check (char_length(google_place_id) between 1 and 300),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('super_admin', 'business_admin')),
  company_id uuid references public.companies(id),
  created_at timestamptz not null default now(),
  check ((role = 'super_admin') = (company_id is null))
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id),
  company_id uuid references public.companies(id), -- null = whole category
  text text not null check (char_length(text) between 1 and 300),
  type text not null check (type in ('single', 'multi', 'scale', 'text')),
  options jsonb check (options is null or jsonb_typeof(options) = 'array'),
  is_required boolean not null default false,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (type not in ('single', 'multi') or (options is not null and jsonb_array_length(options) between 2 and 12))
);

create table public.question_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  requested_by uuid not null references auth.users(id),
  text text not null check (char_length(text) between 1 and 500),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.feedback_submissions (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  company_id uuid not null references public.companies(id),
  rating int not null check (rating between 1 and 5),
  answers jsonb not null default '[]',
  comment text check (char_length(comment) <= 2000),
  contact text check (char_length(contact) <= 200),
  clicked_google boolean not null default false,
  client_hash text,
  created_at timestamptz not null default now()
);

create index on public.companies (category_id);
create index on public.branches (company_id);
create index on public.questions (category_id, is_active);
create index on public.question_requests (company_id, status);
create index on public.feedback_submissions (company_id, created_at desc);
create index on public.feedback_submissions (branch_id, created_at desc);
create index on public.feedback_submissions (company_id, rating);
create index on public.feedback_submissions (branch_id, client_hash, created_at);

-- A company-scoped question must live in that company's category.
create function public.questions_company_matches_category() returns trigger
language plpgsql as $$
begin
  if new.company_id is not null and not exists (
    select 1 from public.companies c where c.id = new.company_id and c.category_id = new.category_id
  ) then
    raise exception 'question company does not belong to question category';
  end if;
  return new;
end $$;
create trigger questions_company_matches_category
  before insert or update on public.questions
  for each row execute function public.questions_company_matches_category();

-- ---------- RLS helpers (security definer avoids recursion on profiles) ----------
create function public.current_app_role() returns text
language sql stable security definer set search_path = public as
$$ select role from public.profiles where user_id = auth.uid() $$;

create function public.current_company_id() returns uuid
language sql stable security definer set search_path = public as
$$ select company_id from public.profiles where user_id = auth.uid() $$;

revoke all on function public.current_app_role(), public.current_company_id() from public;
grant execute on function public.current_app_role(), public.current_company_id() to authenticated;

-- ---------- RLS ----------
alter table public.categories enable row level security;
alter table public.companies enable row level security;
alter table public.branches enable row level security;
alter table public.profiles enable row level security;
alter table public.questions enable row level security;
alter table public.question_requests enable row level security;
alter table public.feedback_submissions enable row level security;

revoke all on public.categories, public.companies, public.branches, public.profiles,
  public.questions, public.question_requests, public.feedback_submissions from anon, authenticated;

grant select, insert, update on public.categories, public.companies, public.branches, public.questions to authenticated;
grant select on public.profiles, public.feedback_submissions to authenticated;
grant select, insert, update on public.question_requests to authenticated;

create policy categories_read on public.categories for select to authenticated
  using (public.current_app_role() is not null);
create policy categories_write on public.categories for all to authenticated
  using (public.current_app_role() = 'super_admin') with check (public.current_app_role() = 'super_admin');

create policy companies_super on public.companies for all to authenticated
  using (public.current_app_role() = 'super_admin') with check (public.current_app_role() = 'super_admin');
create policy companies_own on public.companies for select to authenticated
  using (id = public.current_company_id());

create policy branches_super on public.branches for all to authenticated
  using (public.current_app_role() = 'super_admin') with check (public.current_app_role() = 'super_admin');
create policy branches_own on public.branches for select to authenticated
  using (company_id = public.current_company_id());

create policy profiles_read on public.profiles for select to authenticated
  using (user_id = auth.uid() or public.current_app_role() = 'super_admin');

create policy questions_super on public.questions for all to authenticated
  using (public.current_app_role() = 'super_admin') with check (public.current_app_role() = 'super_admin');
create policy questions_own on public.questions for select to authenticated
  using (
    public.current_app_role() = 'business_admin' and is_active
    and (company_id = public.current_company_id()
         or (company_id is null and category_id = (
              select c.category_id from public.companies c where c.id = public.current_company_id())))
  );

create policy requests_super on public.question_requests for all to authenticated
  using (public.current_app_role() = 'super_admin') with check (public.current_app_role() = 'super_admin');
create policy requests_own_read on public.question_requests for select to authenticated
  using (company_id = public.current_company_id());
create policy requests_own_insert on public.question_requests for insert to authenticated
  with check (
    public.current_app_role() = 'business_admin'
    and company_id = public.current_company_id()
    and requested_by = auth.uid()
    and status = 'pending'
  );

create policy feedback_super on public.feedback_submissions for select to authenticated
  using (public.current_app_role() = 'super_admin');
create policy feedback_own on public.feedback_submissions for select to authenticated
  using (company_id = public.current_company_id());

-- Per-branch totals for dashboards; runs with the caller's RLS.
create view public.branch_stats with (security_invoker = true) as
  select b.id as branch_id, b.company_id, b.name,
         count(f.id) as total,
         round(avg(f.rating)::numeric, 2) as avg_rating,
         count(f.id) filter (where f.rating < 4) as needs_attention,
         count(f.id) filter (where f.clicked_google) as google_clicks
  from public.branches b
  left join public.feedback_submissions f on f.branch_id = b.id
  group by b.id;
grant select on public.branch_stats to authenticated;

-- ---------- Customer RPCs (anonymous) ----------
create function public.get_feedback_form(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'branch_name', b.name,
    'company_name', c.name,
    'google_place_id', b.google_place_id,
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', q.id, 'text', q.text, 'type', q.type,
               'options', q.options, 'is_required', q.is_required)
             order by (q.company_id is not null), q.sort_order, q.created_at)
      from public.questions q
      where q.category_id = c.category_id and q.is_active
        and (q.company_id is null or q.company_id = c.id)
    ), '[]'::jsonb)
  )
  from public.branches b
  join public.companies c on c.id = b.company_id and c.is_active
  join public.categories k on k.id = c.category_id and k.is_active
  where b.slug = p_slug and b.is_active
$$;

create function public.submit_feedback(
  p_slug text, p_rating int, p_answers jsonb, p_comment text, p_contact text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_branch public.branches%rowtype;
  v_company public.companies%rowtype;
  v_q record;
  v_val jsonb;
  v_out jsonb := '[]';
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
  if p_answers is null then p_answers := '{}'; end if;
  if jsonb_typeof(p_answers) <> 'object' then
    raise exception 'invalid answers' using errcode = '22023';
  end if;

  select b.* into v_branch from public.branches b where b.slug = p_slug and b.is_active;
  if not found then raise exception 'unknown branch' using errcode = 'P0002'; end if;
  select c.* into v_company from public.companies c
    join public.categories k on k.id = c.category_id and k.is_active
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

  -- Reject answers to questions that are not on this branch's form.
  if exists (
    select 1 from jsonb_object_keys(p_answers) k
    where not exists (
      select 1 from public.questions q
      where q.id::text = k and q.is_active and q.category_id = v_company.category_id
        and (q.company_id is null or q.company_id = v_company.id))
  ) then
    raise exception 'unknown question' using errcode = '22023';
  end if;

  for v_q in
    select q.* from public.questions q
    where q.category_id = v_company.category_id and q.is_active
      and (q.company_id is null or q.company_id = v_company.id)
    order by (q.company_id is not null), q.sort_order, q.created_at
  loop
    v_val := p_answers -> v_q.id::text;
    if v_val is null or v_val = 'null'::jsonb or v_val = '""'::jsonb or v_val = '[]'::jsonb then
      if v_q.is_required then
        raise exception 'missing answer' using errcode = '22023';
      end if;
      continue;
    end if;

    if v_q.type = 'scale' then
      if jsonb_typeof(v_val) <> 'number' or (v_val #>> '{}')::numeric not in (1, 2, 3, 4, 5) then
        raise exception 'invalid scale answer' using errcode = '22023';
      end if;
    elsif v_q.type = 'text' then
      if jsonb_typeof(v_val) <> 'string' or char_length(v_val #>> '{}') > 1000 then
        raise exception 'invalid text answer' using errcode = '22023';
      end if;
    elsif v_q.type = 'single' then
      if jsonb_typeof(v_val) <> 'string' or not (v_q.options @> to_jsonb(v_val #>> '{}')) then
        raise exception 'invalid choice' using errcode = '22023';
      end if;
    else -- multi
      if jsonb_typeof(v_val) <> 'array' or exists (
        select 1 from jsonb_array_elements(v_val) e
        where jsonb_typeof(e) <> 'string' or not (v_q.options @> e)
      ) then
        raise exception 'invalid choice' using errcode = '22023';
      end if;
    end if;

    v_out := v_out || jsonb_build_object(
      'question_id', v_q.id, 'text', v_q.text, 'type', v_q.type, 'value', v_val);
  end loop;

  insert into public.feedback_submissions
    (branch_id, company_id, rating, answers, comment, contact, client_hash)
  values (v_branch.id, v_branch.company_id, p_rating, v_out, p_comment, p_contact, v_hash)
  returning id into v_id;
  return v_id;
end $$;

create function public.mark_google_click(p_id uuid) returns void
language sql security definer set search_path = public as
$$ update public.feedback_submissions set clicked_google = true where id = p_id $$;

revoke all on function public.get_feedback_form(text), public.submit_feedback(text, int, jsonb, text, text),
  public.mark_google_click(uuid) from public;
grant execute on function public.get_feedback_form(text), public.submit_feedback(text, int, jsonb, text, text),
  public.mark_google_click(uuid) to anon, authenticated;
