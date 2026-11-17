-- =====================================================================================
-- !!! DESTRUCTIVE MIGRATION !!!
-- Replaces per-category/per-company questions with Category -> Subcategory -> Keywords.
-- Applying it WIPES: all feedback submissions, branches, companies, Business Admin logins
-- (auth.users rows + their profiles), questions and question requests.
-- Kept: categories, Super Admin users and their profiles.
-- Apply only deliberately (supabase db reset / db push) after taking a backup.
-- See docs/plans/01-category-subcategory/00-README.md (decisions C1-C7).
-- =====================================================================================

-- ---------- 1. Reset (C1) ----------
-- Old customer RPCs reference the columns/tables removed below; drop them first.
drop function public.get_feedback_form(text);
drop function public.submit_feedback(text, int, jsonb, text, text);

-- question_requests references auth.users (requested_by) and companies, and questions
-- references companies, so both go before users/companies are deleted.
drop table public.question_requests;
drop table public.questions; -- also drops its questions_company_matches_category trigger
drop function public.questions_company_matches_category();

delete from public.feedback_submissions;
delete from public.branches;
-- Business Admin logins: deleting the auth user cascades to its profile (profiles reference companies).
delete from auth.users u
  where u.id in (select p.user_id from public.profiles p where p.role = 'business_admin');
delete from public.companies;

alter table public.companies drop column category_id; -- its index goes with it
alter table public.feedback_submissions drop column answers;

-- ---------- 2. Schema (C2) ----------
alter table public.categories add column sort_order int not null default 0;
create unique index categories_name_lower_key on public.categories (lower(name));

create table public.subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id),
  name text not null check (char_length(name) between 1 and 80),
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index subcategories_category_name_lower_key on public.subcategories (category_id, lower(name));
create index on public.subcategories (category_id);

create table public.keywords (
  id uuid primary key default gen_random_uuid(),
  subcategory_id uuid not null references public.subcategories(id),
  label text not null check (char_length(label) between 1 and 40),
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index keywords_subcategory_label_lower_key on public.keywords (subcategory_id, lower(label));
create index on public.keywords (subcategory_id, is_active);

-- companies is empty after the reset, so no backfill is needed. Category = subcategory's category.
alter table public.companies add column subcategory_id uuid not null references public.subcategories(id);
create index on public.companies (subcategory_id);

-- Snapshot of the chosen keywords: [{id, label}] in the order the customer picked them.
alter table public.feedback_submissions add column keywords jsonb not null default '[]';

-- ---------- RLS / grants (C3): same pattern as categories, no delete, nothing for anon ----------
alter table public.subcategories enable row level security;
alter table public.keywords enable row level security;

revoke all on public.subcategories, public.keywords from anon, authenticated;
grant select, insert, update on public.subcategories, public.keywords to authenticated;

create policy subcategories_read on public.subcategories for select to authenticated
  using (public.current_app_role() is not null);
create policy subcategories_write on public.subcategories for all to authenticated
  using (public.current_app_role() = 'super_admin') with check (public.current_app_role() = 'super_admin');

create policy keywords_read on public.keywords for select to authenticated
  using (public.current_app_role() is not null);
create policy keywords_write on public.keywords for all to authenticated
  using (public.current_app_role() = 'super_admin') with check (public.current_app_role() = 'super_admin');

-- ---------- 3. Seed (C4, C5). Idempotent: unique indexes + on conflict do nothing ----------
insert into public.categories (name, sort_order)
select v.name, v.ord
from (values
  ('Restaurants & Cafes', 1),
  ('Retail', 2),
  ('Healthcare', 3),
  ('Beauty & Wellness', 4),
  ('Hotels & Stays', 5),
  ('Automotive', 6),
  ('Education', 7),
  ('Fitness', 8)
) v(name, ord)
on conflict do nothing;

insert into public.subcategories (category_id, name, sort_order)
select c.id, v.name, v.ord
from (values
  ('Restaurants & Cafes', 'Fine dining', 1),
  ('Restaurants & Cafes', 'Casual dining', 2),
  ('Restaurants & Cafes', 'Cafe', 3),
  ('Restaurants & Cafes', 'Fast food', 4),
  ('Restaurants & Cafes', 'Bakery & Desserts', 5),
  ('Retail', 'Clothing & Fashion', 1),
  ('Retail', 'Electronics', 2),
  ('Retail', 'Grocery & Supermarket', 3),
  ('Retail', 'Home & Furniture', 4),
  ('Healthcare', 'Clinic', 1),
  ('Healthcare', 'Hospital', 2),
  ('Healthcare', 'Dental', 3),
  ('Healthcare', 'Pharmacy', 4),
  ('Healthcare', 'Diagnostics & Lab', 5),
  ('Beauty & Wellness', 'Salon', 1),
  ('Beauty & Wellness', 'Spa & Massage', 2),
  ('Beauty & Wellness', 'Barbershop', 3),
  ('Hotels & Stays', 'Hotel', 1),
  ('Hotels & Stays', 'Resort', 2),
  ('Hotels & Stays', 'Hostel & Guesthouse', 3),
  ('Automotive', 'Showroom', 1),
  ('Automotive', 'Service Center', 2),
  ('Automotive', 'Car Wash', 3),
  ('Education', 'School', 1),
  ('Education', 'Coaching Center', 2),
  ('Education', 'Training Institute', 3),
  ('Fitness', 'Gym', 1),
  ('Fitness', 'Yoga & Studio', 2),
  ('Fitness', 'Sports Club', 3)
) v(category, name, ord)
join public.categories c on lower(c.name) = lower(v.category)
on conflict do nothing;

insert into public.keywords (subcategory_id, label, sort_order)
select s.id, v.label, v.ord
from (values
  -- Restaurants & Cafes
  ('Restaurants & Cafes', 'Fine dining', 'Food quality', 1),
  ('Restaurants & Cafes', 'Fine dining', 'Presentation', 2),
  ('Restaurants & Cafes', 'Fine dining', 'Ambience', 3),
  ('Restaurants & Cafes', 'Fine dining', 'Staff', 4),
  ('Restaurants & Cafes', 'Fine dining', 'Service', 5),
  ('Restaurants & Cafes', 'Fine dining', 'Wine & drinks', 6),
  ('Restaurants & Cafes', 'Fine dining', 'Cleanliness', 7),
  ('Restaurants & Cafes', 'Fine dining', 'Value for money', 8),

  ('Restaurants & Cafes', 'Casual dining', 'Food quality', 1),
  ('Restaurants & Cafes', 'Casual dining', 'Portion size', 2),
  ('Restaurants & Cafes', 'Casual dining', 'Ambience', 3),
  ('Restaurants & Cafes', 'Casual dining', 'Staff', 4),
  ('Restaurants & Cafes', 'Casual dining', 'Service speed', 5),
  ('Restaurants & Cafes', 'Casual dining', 'Cleanliness', 6),
  ('Restaurants & Cafes', 'Casual dining', 'Value for money', 7),

  ('Restaurants & Cafes', 'Cafe', 'Coffee quality', 1),
  ('Restaurants & Cafes', 'Cafe', 'Ambience', 2),
  ('Restaurants & Cafes', 'Cafe', 'Staff', 3),
  ('Restaurants & Cafes', 'Cafe', 'Service speed', 4),
  ('Restaurants & Cafes', 'Cafe', 'Cleanliness', 5),
  ('Restaurants & Cafes', 'Cafe', 'Value for money', 6),
  ('Restaurants & Cafes', 'Cafe', 'Seating', 7),

  ('Restaurants & Cafes', 'Fast food', 'Food quality', 1),
  ('Restaurants & Cafes', 'Fast food', 'Order accuracy', 2),
  ('Restaurants & Cafes', 'Fast food', 'Service speed', 3),
  ('Restaurants & Cafes', 'Fast food', 'Staff', 4),
  ('Restaurants & Cafes', 'Fast food', 'Cleanliness', 5),
  ('Restaurants & Cafes', 'Fast food', 'Packaging', 6),
  ('Restaurants & Cafes', 'Fast food', 'Value for money', 7),

  ('Restaurants & Cafes', 'Bakery & Desserts', 'Taste', 1),
  ('Restaurants & Cafes', 'Bakery & Desserts', 'Freshness', 2),
  ('Restaurants & Cafes', 'Bakery & Desserts', 'Variety', 3),
  ('Restaurants & Cafes', 'Bakery & Desserts', 'Presentation', 4),
  ('Restaurants & Cafes', 'Bakery & Desserts', 'Staff', 5),
  ('Restaurants & Cafes', 'Bakery & Desserts', 'Cleanliness', 6),
  ('Restaurants & Cafes', 'Bakery & Desserts', 'Value for money', 7),

  -- Retail
  ('Retail', 'Clothing & Fashion', 'Product quality', 1),
  ('Retail', 'Clothing & Fashion', 'Variety', 2),
  ('Retail', 'Clothing & Fashion', 'Fitting rooms', 3),
  ('Retail', 'Clothing & Fashion', 'Staff', 4),
  ('Retail', 'Clothing & Fashion', 'Store layout', 5),
  ('Retail', 'Clothing & Fashion', 'Billing speed', 6),
  ('Retail', 'Clothing & Fashion', 'Value for money', 7),

  ('Retail', 'Electronics', 'Product range', 1),
  ('Retail', 'Electronics', 'Product knowledge', 2),
  ('Retail', 'Electronics', 'Staff', 3),
  ('Retail', 'Electronics', 'Demo & display', 4),
  ('Retail', 'Electronics', 'Billing speed', 5),
  ('Retail', 'Electronics', 'After-sales support', 6),
  ('Retail', 'Electronics', 'Value for money', 7),

  ('Retail', 'Grocery & Supermarket', 'Freshness', 1),
  ('Retail', 'Grocery & Supermarket', 'Product range', 2),
  ('Retail', 'Grocery & Supermarket', 'Stock availability', 3),
  ('Retail', 'Grocery & Supermarket', 'Cleanliness', 4),
  ('Retail', 'Grocery & Supermarket', 'Billing speed', 5),
  ('Retail', 'Grocery & Supermarket', 'Staff', 6),
  ('Retail', 'Grocery & Supermarket', 'Value for money', 7),

  ('Retail', 'Home & Furniture', 'Product quality', 1),
  ('Retail', 'Home & Furniture', 'Design range', 2),
  ('Retail', 'Home & Furniture', 'Staff', 3),
  ('Retail', 'Home & Furniture', 'Showroom display', 4),
  ('Retail', 'Home & Furniture', 'Delivery', 5),
  ('Retail', 'Home & Furniture', 'Installation', 6),
  ('Retail', 'Home & Furniture', 'Value for money', 7),

  -- Healthcare
  ('Healthcare', 'Clinic', 'Doctor', 1),
  ('Healthcare', 'Clinic', 'Consultation', 2),
  ('Healthcare', 'Clinic', 'Waiting time', 3),
  ('Healthcare', 'Clinic', 'Staff', 4),
  ('Healthcare', 'Clinic', 'Cleanliness', 5),
  ('Healthcare', 'Clinic', 'Appointment booking', 6),
  ('Healthcare', 'Clinic', 'Fees', 7),

  ('Healthcare', 'Hospital', 'Doctors', 1),
  ('Healthcare', 'Hospital', 'Nursing care', 2),
  ('Healthcare', 'Hospital', 'Waiting time', 3),
  ('Healthcare', 'Hospital', 'Cleanliness', 4),
  ('Healthcare', 'Hospital', 'Admission process', 5),
  ('Healthcare', 'Hospital', 'Facilities', 6),
  ('Healthcare', 'Hospital', 'Staff', 7),
  ('Healthcare', 'Hospital', 'Billing', 8),

  ('Healthcare', 'Dental', 'Dentist', 1),
  ('Healthcare', 'Dental', 'Treatment', 2),
  ('Healthcare', 'Dental', 'Pain management', 3),
  ('Healthcare', 'Dental', 'Waiting time', 4),
  ('Healthcare', 'Dental', 'Hygiene', 5),
  ('Healthcare', 'Dental', 'Staff', 6),
  ('Healthcare', 'Dental', 'Fees', 7),

  ('Healthcare', 'Pharmacy', 'Medicine availability', 1),
  ('Healthcare', 'Pharmacy', 'Pharmacist advice', 2),
  ('Healthcare', 'Pharmacy', 'Staff', 3),
  ('Healthcare', 'Pharmacy', 'Billing speed', 4),
  ('Healthcare', 'Pharmacy', 'Cleanliness', 5),
  ('Healthcare', 'Pharmacy', 'Pricing', 6),

  ('Healthcare', 'Diagnostics & Lab', 'Sample collection', 1),
  ('Healthcare', 'Diagnostics & Lab', 'Report turnaround', 2),
  ('Healthcare', 'Diagnostics & Lab', 'Waiting time', 3),
  ('Healthcare', 'Diagnostics & Lab', 'Staff', 4),
  ('Healthcare', 'Diagnostics & Lab', 'Hygiene', 5),
  ('Healthcare', 'Diagnostics & Lab', 'Home collection', 6),
  ('Healthcare', 'Diagnostics & Lab', 'Pricing', 7),

  -- Beauty & Wellness
  ('Beauty & Wellness', 'Salon', 'Haircut & styling', 1),
  ('Beauty & Wellness', 'Salon', 'Stylist', 2),
  ('Beauty & Wellness', 'Salon', 'Hygiene', 3),
  ('Beauty & Wellness', 'Salon', 'Ambience', 4),
  ('Beauty & Wellness', 'Salon', 'Waiting time', 5),
  ('Beauty & Wellness', 'Salon', 'Products used', 6),
  ('Beauty & Wellness', 'Salon', 'Value for money', 7),

  ('Beauty & Wellness', 'Spa & Massage', 'Therapist', 1),
  ('Beauty & Wellness', 'Spa & Massage', 'Massage quality', 2),
  ('Beauty & Wellness', 'Spa & Massage', 'Ambience', 3),
  ('Beauty & Wellness', 'Spa & Massage', 'Hygiene', 4),
  ('Beauty & Wellness', 'Spa & Massage', 'Staff', 5),
  ('Beauty & Wellness', 'Spa & Massage', 'Relaxation', 6),
  ('Beauty & Wellness', 'Spa & Massage', 'Value for money', 7),

  ('Beauty & Wellness', 'Barbershop', 'Haircut', 1),
  ('Beauty & Wellness', 'Barbershop', 'Beard grooming', 2),
  ('Beauty & Wellness', 'Barbershop', 'Barber', 3),
  ('Beauty & Wellness', 'Barbershop', 'Hygiene', 4),
  ('Beauty & Wellness', 'Barbershop', 'Waiting time', 5),
  ('Beauty & Wellness', 'Barbershop', 'Ambience', 6),
  ('Beauty & Wellness', 'Barbershop', 'Value for money', 7),

  -- Hotels & Stays
  ('Hotels & Stays', 'Hotel', 'Room', 1),
  ('Hotels & Stays', 'Hotel', 'Cleanliness', 2),
  ('Hotels & Stays', 'Hotel', 'Front desk', 3),
  ('Hotels & Stays', 'Hotel', 'Breakfast', 4),
  ('Hotels & Stays', 'Hotel', 'Location', 5),
  ('Hotels & Stays', 'Hotel', 'Amenities', 6),
  ('Hotels & Stays', 'Hotel', 'Staff', 7),
  ('Hotels & Stays', 'Hotel', 'Value for money', 8),

  ('Hotels & Stays', 'Resort', 'Rooms', 1),
  ('Hotels & Stays', 'Resort', 'Pool & facilities', 2),
  ('Hotels & Stays', 'Resort', 'Food', 3),
  ('Hotels & Stays', 'Resort', 'Activities', 4),
  ('Hotels & Stays', 'Resort', 'Views', 5),
  ('Hotels & Stays', 'Resort', 'Staff', 6),
  ('Hotels & Stays', 'Resort', 'Cleanliness', 7),
  ('Hotels & Stays', 'Resort', 'Value for money', 8),

  ('Hotels & Stays', 'Hostel & Guesthouse', 'Beds', 1),
  ('Hotels & Stays', 'Hostel & Guesthouse', 'Bathrooms', 2),
  ('Hotels & Stays', 'Hostel & Guesthouse', 'Cleanliness', 3),
  ('Hotels & Stays', 'Hostel & Guesthouse', 'Common areas', 4),
  ('Hotels & Stays', 'Hostel & Guesthouse', 'Host', 5),
  ('Hotels & Stays', 'Hostel & Guesthouse', 'Location', 6),
  ('Hotels & Stays', 'Hostel & Guesthouse', 'Value for money', 7),

  -- Automotive
  ('Automotive', 'Showroom', 'Sales staff', 1),
  ('Automotive', 'Showroom', 'Product knowledge', 2),
  ('Automotive', 'Showroom', 'Test drive', 3),
  ('Automotive', 'Showroom', 'Showroom', 4),
  ('Automotive', 'Showroom', 'Paperwork', 5),
  ('Automotive', 'Showroom', 'Delivery', 6),
  ('Automotive', 'Showroom', 'Pricing transparency', 7),

  ('Automotive', 'Service Center', 'Service quality', 1),
  ('Automotive', 'Service Center', 'Turnaround time', 2),
  ('Automotive', 'Service Center', 'Service advisor', 3),
  ('Automotive', 'Service Center', 'Pricing transparency', 4),
  ('Automotive', 'Service Center', 'Cleanliness', 5),
  ('Automotive', 'Service Center', 'Customer lounge', 6),
  ('Automotive', 'Service Center', 'Billing', 7),

  ('Automotive', 'Car Wash', 'Wash quality', 1),
  ('Automotive', 'Car Wash', 'Interior cleaning', 2),
  ('Automotive', 'Car Wash', 'Attention to detail', 3),
  ('Automotive', 'Car Wash', 'Waiting time', 4),
  ('Automotive', 'Car Wash', 'Staff', 5),
  ('Automotive', 'Car Wash', 'Pricing', 6),

  -- Education
  ('Education', 'School', 'Teachers', 1),
  ('Education', 'School', 'Curriculum', 2),
  ('Education', 'School', 'Facilities', 3),
  ('Education', 'School', 'Safety', 4),
  ('Education', 'School', 'Communication', 5),
  ('Education', 'School', 'Extracurriculars', 6),
  ('Education', 'School', 'Administration', 7),

  ('Education', 'Coaching Center', 'Faculty', 1),
  ('Education', 'Coaching Center', 'Study material', 2),
  ('Education', 'Coaching Center', 'Doubt clearing', 3),
  ('Education', 'Coaching Center', 'Batch size', 4),
  ('Education', 'Coaching Center', 'Results', 5),
  ('Education', 'Coaching Center', 'Schedule', 6),
  ('Education', 'Coaching Center', 'Fees', 7),

  ('Education', 'Training Institute', 'Trainers', 1),
  ('Education', 'Training Institute', 'Course content', 2),
  ('Education', 'Training Institute', 'Hands-on practice', 3),
  ('Education', 'Training Institute', 'Placement support', 4),
  ('Education', 'Training Institute', 'Facilities', 5),
  ('Education', 'Training Institute', 'Schedule', 6),
  ('Education', 'Training Institute', 'Fees', 7),

  -- Fitness
  ('Fitness', 'Gym', 'Equipment', 1),
  ('Fitness', 'Gym', 'Trainers', 2),
  ('Fitness', 'Gym', 'Cleanliness', 3),
  ('Fitness', 'Gym', 'Crowd level', 4),
  ('Fitness', 'Gym', 'Locker rooms', 5),
  ('Fitness', 'Gym', 'Timings', 6),
  ('Fitness', 'Gym', 'Membership value', 7),

  ('Fitness', 'Yoga & Studio', 'Instructor', 1),
  ('Fitness', 'Yoga & Studio', 'Class quality', 2),
  ('Fitness', 'Yoga & Studio', 'Ambience', 3),
  ('Fitness', 'Yoga & Studio', 'Cleanliness', 4),
  ('Fitness', 'Yoga & Studio', 'Batch timings', 5),
  ('Fitness', 'Yoga & Studio', 'Class size', 6),
  ('Fitness', 'Yoga & Studio', 'Membership value', 7),

  ('Fitness', 'Sports Club', 'Facilities', 1),
  ('Fitness', 'Sports Club', 'Coaches', 2),
  ('Fitness', 'Sports Club', 'Maintenance', 3),
  ('Fitness', 'Sports Club', 'Court booking', 4),
  ('Fitness', 'Sports Club', 'Changing rooms', 5),
  ('Fitness', 'Sports Club', 'Staff', 6),
  ('Fitness', 'Sports Club', 'Membership value', 7)
) v(category, subcategory, label, ord)
join public.categories c on lower(c.name) = lower(v.category)
join public.subcategories s on s.category_id = c.id and lower(s.name) = lower(v.subcategory)
on conflict do nothing;

-- ---------- 4. Customer RPCs (C6, C7). Anonymous callers only ever use these. ----------
-- Not found (null) when the branch, company, subcategory or category is inactive.
create function public.get_feedback_form(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'branch_name', b.name,
    'company_name', c.name,
    'google_place_id', b.google_place_id,
    'category_name', k.name,
    'subcategory_name', s.name,
    'keywords', coalesce((
      select jsonb_agg(jsonb_build_object('id', w.id, 'label', w.label) order by w.sort_order, w.label)
      from public.keywords w
      where w.subcategory_id = s.id and w.is_active
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
  v_subcategory_id uuid;
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
  if cardinality(v_ids) > 8 then
    raise exception 'too many keywords' using errcode = '22023';
  end if;

  select b.* into v_branch from public.branches b where b.slug = p_slug and b.is_active;
  if not found then raise exception 'unknown branch' using errcode = 'P0002'; end if;
  select c.subcategory_id into v_subcategory_id
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

  -- Every id must be an active keyword of this company's subcategory.
  if (select count(*) from public.keywords w
      where w.id = any(v_ids) and w.is_active and w.subcategory_id = v_subcategory_id)
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
