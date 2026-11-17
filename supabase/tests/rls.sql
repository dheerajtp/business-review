-- Run after stubs + migration. Any failed assertion aborts with an error.
\set ON_ERROR_STOP on
create temp table _ids (k text primary key, v uuid);
grant all on _ids to anon, authenticated;

\echo '--- seed: 8 categories, C4 subcategories, 6-8 active keywords each, idempotent'
do $$ begin
  assert (select count(*) from categories) = 8, 'seed has 8 categories, got ' || (select count(*) from categories);
  assert (select count(*) from subcategories) = 29, 'seed has 29 subcategories, got ' || (select count(*) from subcategories);
  assert (select count(*) from subcategories s join categories c on c.id = s.category_id
          where c.name = 'Restaurants & Cafes') = 5, 'Restaurants & Cafes has 5 subcategories';
  assert not exists (
    select 1 from subcategories s
    where (select count(*) from keywords w where w.subcategory_id = s.id and w.is_active) not between 6 and 8
  ), 'every subcategory has 6-8 active keywords';
  assert not exists (select 1 from categories c where not exists (select 1 from subcategories s where s.category_id = c.id)),
    'every category has subcategories';
end $$;
create temp table _seed_counts as
  select (select count(*) from categories) c, (select count(*) from subcategories) s, (select count(*) from keywords) k;
-- re-running seed-style inserts (any letter case) changes nothing
insert into categories (name) values ('RETAIL') on conflict do nothing;
insert into subcategories (category_id, name)
  select id, 'cafe' from categories where name = 'Restaurants & Cafes' on conflict do nothing;
insert into keywords (subcategory_id, label)
  select s.id, 'coffee QUALITY' from subcategories s where s.name = 'Cafe' on conflict do nothing;
do $$ begin
  assert (select c from _seed_counts) = (select count(*) from categories), 'seed re-run added a category';
  assert (select s from _seed_counts) = (select count(*) from subcategories), 'seed re-run added a subcategory';
  assert (select k from _seed_counts) = (select count(*) from keywords), 'seed re-run added a keyword';
end $$;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'super@x'),
  ('00000000-0000-0000-0000-0000000000b1', 'cafe@x'),
  ('00000000-0000-0000-0000-0000000000b2', 'boutique@x');

insert into categories (id, name) values
  ('10000000-0000-0000-0000-000000000001', 'Cafe'),
  ('10000000-0000-0000-0000-000000000002', 'Boutique');
insert into subcategories (id, category_id, name) values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Espresso bar'),
  ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Sarees'),
  ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'Tea room');
-- Espresso bar: 9 active keywords (one more than the submit cap) + 1 archived.
insert into keywords (id, subcategory_id, label, sort_order, is_active) values
  ('60000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'Coffee', 1, true),
  ('60000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', 'Ambience', 2, true),
  ('60000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000001', 'Staff', 3, true),
  ('60000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000001', 'Old menu', 4, false),
  ('60000000-0000-0000-0000-000000000007', '50000000-0000-0000-0000-000000000001', 'Seating', 5, true),
  ('60000000-0000-0000-0000-000000000008', '50000000-0000-0000-0000-000000000001', 'Music', 6, true),
  ('60000000-0000-0000-0000-000000000009', '50000000-0000-0000-0000-000000000001', 'Wifi', 7, true),
  ('60000000-0000-0000-0000-00000000000a', '50000000-0000-0000-0000-000000000001', 'Cleanliness', 8, true),
  ('60000000-0000-0000-0000-00000000000b', '50000000-0000-0000-0000-000000000001', 'Pastries', 9, true),
  -- same sort_order as Pastries: ties are broken by label, so Location comes before Pastries
  ('60000000-0000-0000-0000-00000000000c', '50000000-0000-0000-0000-000000000001', 'Location', 9, true),
  ('60000000-0000-0000-0000-000000000005', '50000000-0000-0000-0000-000000000002', 'Fabric', 1, true),
  ('60000000-0000-0000-0000-000000000006', '50000000-0000-0000-0000-000000000003', 'Tea', 1, true);
insert into companies (id, name, subcategory_id) values
  ('20000000-0000-0000-0000-000000000001', 'Brew Co', '50000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002', 'Silk House', '50000000-0000-0000-0000-000000000002');
insert into branches (id, company_id, name, slug, google_place_id) values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Brew MG Road', 'brew1', 'PLACE_BREW'),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'Silk Mall', 'silk1', 'PLACE_SILK');
insert into profiles (user_id, role, company_id) values
  ('00000000-0000-0000-0000-0000000000a1', 'super_admin', null),
  ('00000000-0000-0000-0000-0000000000b1', 'business_admin', '20000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-0000000000b2', 'business_admin', '20000000-0000-0000-0000-000000000002');

-- helper: run a statement as a given role / user, expect success or a message fragment
create function pg_temp.as_user(u text, r text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, false);
  execute format('set role %I', r);
end $$;

\echo '--- anon cannot read tables'
set role anon;
do $$ begin
  begin perform 1 from feedback_submissions; raise exception 'FAIL anon read feedback';
  exception when insufficient_privilege then null; end;
  begin perform 1 from branches; raise exception 'FAIL anon read branches';
  exception when insufficient_privilege then null; end;
  begin insert into feedback_submissions (branch_id, company_id, rating) values
    ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',5);
    raise exception 'FAIL anon insert';
  exception when insufficient_privilege then null; end;
  begin perform 1 from subcategories; raise exception 'FAIL anon read subcategories';
  exception when insufficient_privilege then null; end;
  begin perform 1 from keywords; raise exception 'FAIL anon read keywords';
  exception when insufficient_privilege then null; end;
  begin insert into subcategories (category_id, name) values ('10000000-0000-0000-0000-000000000001', 'x');
    raise exception 'FAIL anon insert subcategory';
  exception when insufficient_privilege then null; end;
  begin insert into keywords (subcategory_id, label) values ('50000000-0000-0000-0000-000000000001', 'x');
    raise exception 'FAIL anon insert keyword';
  exception when insufficient_privilege then null; end;
  begin update keywords set label = 'x'; raise exception 'FAIL anon update keyword';
  exception when insufficient_privilege then null; end;
end $$;

\echo '--- form RPC: names, active keywords ordered by sort_order then label, no leakage'
do $$
declare f jsonb;
begin
  f := get_feedback_form('brew1');
  assert f->>'branch_name' = 'Brew MG Road', 'branch name';
  assert f->>'company_name' = 'Brew Co', 'company name';
  assert f->>'google_place_id' = 'PLACE_BREW', 'place id';
  assert f->>'category_name' = 'Cafe', 'category name';
  assert f->>'subcategory_name' = 'Espresso bar', 'subcategory name';
  assert jsonb_array_length(f->'keywords') = 9, 'brew should have 9 active keywords, got ' || jsonb_array_length(f->'keywords');
  assert f->'keywords'->0 = '{"id": "60000000-0000-0000-0000-000000000001", "label": "Coffee"}'::jsonb, 'first keyword is {id,label}';
  assert (select array_agg(e->>'label' order by n) from jsonb_array_elements(f->'keywords') with ordinality t(e, n))
         = array['Coffee','Ambience','Staff','Seating','Music','Wifi','Cleanliness','Location','Pastries'],
         'ordered by sort_order, label';
  assert not exists (select 1 from jsonb_array_elements(f->'keywords') e where e->>'label' in ('Old menu', 'Tea', 'Fabric')),
         'no archived or other-subcategory keywords';
  f := get_feedback_form('silk1');
  assert f->'keywords' = '[{"id": "60000000-0000-0000-0000-000000000005", "label": "Fabric"}]'::jsonb, 'silk has 1 keyword';
  assert get_feedback_form('nope') is null, 'unknown slug null';
end $$;

\echo '--- submit: valid, duplicate, foreign, archived, too many, invalid'
do $$
declare id uuid;
begin
  -- duplicates are collapsed; order is the order first picked
  id := submit_feedback('brew1', 2,
    array['60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000001',
          '60000000-0000-0000-0000-000000000002']::uuid[],
    'slow service', '98765');
  assert id is not null;

  begin perform submit_feedback('brew1', 0, '{}'::uuid[], null, null);
    raise exception 'FAIL rating 0'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 6, '{}'::uuid[], null, null);
    raise exception 'FAIL rating 6'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, array['60000000-0000-0000-0000-000000000005']::uuid[], null, null);
    raise exception 'FAIL keyword of another category'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, array['60000000-0000-0000-0000-000000000006']::uuid[], null, null);
    raise exception 'FAIL keyword of another subcategory in the same category'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5,
    array['60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000004']::uuid[], null, null);
    raise exception 'FAIL archived keyword'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, array[gen_random_uuid()], null, null);
    raise exception 'FAIL random keyword id'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, array[null]::uuid[], null, null);
    raise exception 'FAIL null keyword id'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, (select array_agg(e->>'id')::uuid[] from jsonb_array_elements(get_feedback_form('brew1')->'keywords') e), null, null);
    raise exception 'FAIL 9 keywords'; exception when sqlstate '22023' then
      assert sqlerrm = 'too many keywords', 'too many message, got ' || sqlerrm; end;
  begin perform submit_feedback('brew1', 5, '{}'::uuid[], repeat('x', 2001), null);
    raise exception 'FAIL long comment'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, '{}'::uuid[], null, repeat('x', 201));
    raise exception 'FAIL long contact'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('nope', 5, '{}'::uuid[], null, null);
    raise exception 'FAIL unknown slug'; exception when sqlstate 'P0002' then null; end;
  -- keywords are optional; null means none
  perform submit_feedback('silk1', 5, null, null, null);
  perform mark_google_click(id);
end $$;

reset role;
do $$ begin
  assert (select count(*) from feedback_submissions) = 2, 'exactly 2 stored (invalid ones rejected)';
  assert (select clicked_google from feedback_submissions where rating = 2), 'click recorded';
  assert (select company_id from feedback_submissions where rating = 5) = '20000000-0000-0000-0000-000000000002', 'company derived server-side';
  assert (select keywords from feedback_submissions where rating = 2) =
    '[{"id": "60000000-0000-0000-0000-000000000002", "label": "Ambience"},
      {"id": "60000000-0000-0000-0000-000000000001", "label": "Coffee"}]'::jsonb, 'snapshot, deduped, in submitted order';
  assert (select keywords from feedback_submissions where rating = 5) = '[]'::jsonb, 'no keywords stored as []';
end $$;
-- label snapshot survives a later rename
update keywords set label = 'Espresso' where id = '60000000-0000-0000-0000-000000000001';
do $$ begin
  assert (select keywords->1->>'label' from feedback_submissions where rating = 2) = 'Coffee', 'label snapshot kept';
end $$;
update keywords set label = 'Coffee' where id = '60000000-0000-0000-0000-000000000001';

\echo '--- inactive branch/company/subcategory/category are hidden and reject'
create function pg_temp.check_silk_hidden(what text) returns void language plpgsql as $$
begin
  set local role anon;
  assert get_feedback_form('silk1') is null, what || ': form should be null';
  begin perform submit_feedback('silk1', 5, null, null, null); raise exception 'FAIL inactive %', what;
  exception when sqlstate 'P0002' then null; end;
  reset role;
end $$;
update branches set is_active = false where slug = 'silk1';
select pg_temp.check_silk_hidden('branch');
update branches set is_active = true where slug = 'silk1';
update companies set is_active = false where id = '20000000-0000-0000-0000-000000000002';
select pg_temp.check_silk_hidden('company');
update companies set is_active = true where id = '20000000-0000-0000-0000-000000000002';
update subcategories set is_active = false where id = '50000000-0000-0000-0000-000000000002';
select pg_temp.check_silk_hidden('subcategory');
update subcategories set is_active = true where id = '50000000-0000-0000-0000-000000000002';
update categories set is_active = false where id = '10000000-0000-0000-0000-000000000002';
select pg_temp.check_silk_hidden('category');
update categories set is_active = true where id = '10000000-0000-0000-0000-000000000002';
reset role;
do $$ begin
  assert get_feedback_form('silk1') is not null, 'silk visible again';
end $$;

\echo '--- business admin isolation; taxonomy is read-only'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$ begin
  assert (select count(*) from feedback_submissions) = 1, 'BA1 sees only own feedback';
  assert (select count(*) from branches) = 1, 'BA1 sees only own branches';
  assert (select count(*) from companies) = 1;
  assert (select count(*) from branch_stats) = 1, 'stats scoped';
  assert (select count(*) from subcategories) = 32, 'BA reads all subcategories';
  assert (select count(*) from keywords where subcategory_id = '50000000-0000-0000-0000-000000000001') = 10, 'BA reads keywords';
  begin update branches set google_place_id = 'EVIL' where true;
    assert (select count(*) from branches where google_place_id = 'EVIL') = 0, 'FAIL BA update branch';
  exception when insufficient_privilege then null; end;
  begin insert into subcategories (category_id, name) values ('10000000-0000-0000-0000-000000000001', 'x');
    raise exception 'FAIL BA insert subcategory'; exception when insufficient_privilege then null; end;
  begin insert into keywords (subcategory_id, label) values ('50000000-0000-0000-0000-000000000001', 'x');
    raise exception 'FAIL BA insert keyword'; exception when insufficient_privilege then null; end;
  update subcategories set name = 'EVIL' where true;
  assert not exists (select 1 from subcategories where name = 'EVIL'), 'FAIL BA update subcategory';
  update keywords set label = 'EVIL', is_active = false where true;
  assert not exists (select 1 from keywords where label = 'EVIL' or not is_active and id <> '60000000-0000-0000-0000-000000000004'),
    'FAIL BA update keyword';
  begin delete from keywords; raise exception 'FAIL BA delete keyword';
  exception when insufficient_privilege then null; end;
  begin delete from feedback_submissions; raise exception 'FAIL BA delete feedback';
  exception when insufficient_privilege then null; end;
  begin update feedback_submissions set rating = 5; raise exception 'FAIL BA update feedback';
  exception when insufficient_privilege then null; end;
  begin insert into profiles (user_id, role) values (gen_random_uuid(), 'super_admin');
    raise exception 'FAIL BA insert profile'; exception when insufficient_privilege then null; end;
end $$;
reset role;

\echo '--- business admin 2 sees only own feedback; super sees everything and edits taxonomy'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'authenticated');
do $$ begin
  assert (select count(*) from feedback_submissions) = 1;
  assert (select company_id from feedback_submissions) = '20000000-0000-0000-0000-000000000002';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  assert (select count(*) from feedback_submissions) = 2;
  assert (select count(*) from companies) = 2;
  insert into subcategories (id, category_id, name, sort_order)
    values ('50000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000001', 'Roastery', 3);
  insert into keywords (id, subcategory_id, label, sort_order)
    values ('60000000-0000-0000-0000-000000000099', '50000000-0000-0000-0000-000000000009', 'Beans', 1);
  update subcategories set name = 'Roastery & Bar' where id = '50000000-0000-0000-0000-000000000009';
  update keywords set is_active = false where id = '60000000-0000-0000-0000-000000000099';
  assert (select name from subcategories where id = '50000000-0000-0000-0000-000000000009') = 'Roastery & Bar', 'super renames';
  assert not (select is_active from keywords where id = '60000000-0000-0000-0000-000000000099'), 'super archives';
  begin insert into keywords (subcategory_id, label) values ('50000000-0000-0000-0000-000000000009', 'BEANS');
    raise exception 'FAIL duplicate keyword label'; exception when unique_violation then null; end;
  begin delete from keywords where id = '60000000-0000-0000-0000-000000000099'; raise exception 'FAIL super delete keyword';
  exception when insufficient_privilege then null; end;
  begin delete from subcategories where id = '50000000-0000-0000-0000-000000000009'; raise exception 'FAIL super delete subcategory';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

\echo '--- last_seen: own row only, no direct profile updates'
update profiles set last_seen_at = '2000-01-01';
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$
declare t timestamptz; other timestamptz;
begin
  t := mark_feedback_seen();
  assert t is not null and t > now() - interval '1 minute', 'returns fresh timestamp';
  assert (select last_seen_at from profiles where user_id = auth.uid()) = t, 'own row updated';
  begin update profiles set role = 'super_admin' where user_id = auth.uid();
    raise exception 'FAIL BA direct profile update'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
  assert (select count(*) from profiles where last_seen_at > now() - interval '1 minute') = 1, 'only the caller row was touched';
end $$;
-- anon cannot call it
set role anon;
do $$ begin
  begin perform mark_feedback_seen(); raise exception 'FAIL anon mark_feedback_seen';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

\echo '--- list_business_admins: super only'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  assert (select count(*) from list_business_admins('20000000-0000-0000-0000-000000000001')) = 1, 'super sees the 1 login';
  assert (select email from list_business_admins('20000000-0000-0000-0000-000000000001')) = 'cafe@x', 'right email';
  assert (select count(*) from list_business_admins('20000000-0000-0000-0000-000000000002')) = 1, 'other company has its own';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$ begin
  assert (select count(*) from list_business_admins('20000000-0000-0000-0000-000000000001')) = 0, 'BA gets nothing, not even own company';
  assert (select count(*) from list_business_admins('20000000-0000-0000-0000-000000000002')) = 0, 'BA gets nothing for others';
end $$;
reset role;
set role anon;
do $$ begin
  begin perform * from list_business_admins('20000000-0000-0000-0000-000000000001'); raise exception 'FAIL anon list';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

\echo '--- dashboard_stats: totals, zero-filled days, RLS scoping'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare r jsonb;
begin
  r := dashboard_stats(30, null, 'UTC');
  assert (r->'summary'->'cur'->>'total')::int = 2, 'super sees both submissions';
  assert (r->'summary'->'cur'->>'low')::int = 1 and (r->'summary'->'cur'->>'happy')::int = 1, 'low/happy split';
  assert (r->'summary'->'cur'->>'google')::int = 0, 'google clicks count only 4-5 star customers (the fixture click was a 2-star)';
  assert jsonb_array_length(r->'daily') = 30, 'daily is zero-filled to 30 days';
  assert (select sum((e->>'high')::int + (e->>'low')::int) from jsonb_array_elements(r->'daily') e) = 2, 'daily sums to total';
  assert (select sum((e->>'n')::int) from jsonb_array_elements(r->'mix') e) = 2, 'mix sums to total';
  assert jsonb_array_length(r->'mix') = 5, 'mix has 5 rows';
  assert jsonb_array_length(r->'companies') = 2 and jsonb_array_length(r->'branches') = 2, 'all companies and branches';
  assert (dashboard_stats(7, null, 'UTC')->>'days')::int = 7, 'days honoured';
  assert (dashboard_stats(100000, null, 'UTC')->>'days')::int = 365, 'days clamped';
  r := dashboard_stats(30, '20000000-0000-0000-0000-000000000001', 'Asia/Kolkata');
  assert (r->'summary'->'cur'->>'total')::int = 1 and jsonb_array_length(r->'companies') = 1, 'company filter';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$
declare r jsonb;
begin
  r := dashboard_stats(30, null, 'UTC');
  assert (r->'summary'->'cur'->>'total')::int = 1, 'BA only sees own company numbers';
  assert jsonb_array_length(r->'companies') = 1 and jsonb_array_length(r->'branches') = 1, 'BA sees only own company/branch rows';
  r := dashboard_stats(30, '20000000-0000-0000-0000-000000000002', 'UTC');
  assert (r->'summary'->'cur'->>'total')::int = 0 and jsonb_array_length(r->'companies') = 0, 'BA cannot peek at another company by passing its id';
end $$;
reset role;
set role anon;
do $$ begin
  begin perform dashboard_stats(30, null, 'UTC'); raise exception 'FAIL anon dashboard';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

\echo '--- user without profile sees nothing'
select pg_temp.as_user('00000000-0000-0000-0000-00000000dead', 'authenticated');
do $$ begin
  assert (select count(*) from categories) = 0;
  assert (select count(*) from subcategories) = 0;
  assert (select count(*) from keywords) = 0;
  assert (select count(*) from feedback_submissions) = 0;
end $$;
reset role;
\echo 'ALL RLS TESTS PASSED'
