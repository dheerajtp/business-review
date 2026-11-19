-- Run after stubs + migration. Any failed assertion aborts with an error.
\set ON_ERROR_STOP on
create temp table _ids (k text primary key, v uuid);
grant all on _ids to anon, authenticated;

\echo '--- seed: 8 categories, C4 subcategories, keyword library (General >= 10, 6-8 per category), idempotent'
do $$ begin
  assert (select count(*) from categories) = 8, 'seed has 8 categories, got ' || (select count(*) from categories);
  assert (select count(*) from subcategories) = 29, 'seed has 29 subcategories, got ' || (select count(*) from subcategories);
  assert (select count(*) from subcategories s join categories c on c.id = s.category_id
          where c.name = 'Restaurants & Cafes') = 5, 'Restaurants & Cafes has 5 subcategories';
  assert not exists (select 1 from categories c where not exists (select 1 from subcategories s where s.category_id = c.id)),
    'every category has subcategories';
  assert (select count(*) from keywords where category_id is null and is_active) >= 10,
    'General has >= 10 keywords, got ' || (select count(*) from keywords where category_id is null);
  assert not exists (
    select 1 from categories c
    where (select count(*) from keywords w where w.category_id = c.id and w.is_active) not between 6 and 8
  ), 'every category has 6-8 active keywords';
  assert not exists (select 1 from keywords where label <> lower(label) or char_length(label) > 60),
    'seed labels are lower case and <= 60 chars';
  assert not exists (select 1 from branch_keywords), 'no branch picks after migration';
  assert not exists (select 1 from company_keywords), 'no company picks after migration';
end $$;
create temp table _seed_counts as
  select (select count(*) from categories) c, (select count(*) from subcategories) s, (select count(*) from keywords) k;
-- re-running seed-style inserts (any letter case) changes nothing
insert into categories (name) values ('RETAIL') on conflict do nothing;
insert into subcategories (category_id, name)
  select id, 'cafe' from categories where name = 'Restaurants & Cafes' on conflict do nothing;
insert into keywords (label) values ('FRIENDLY Staff') on conflict do nothing;
insert into keywords (category_id, label)
  select id, 'Best Coffee In Town' from categories where name = 'Restaurants & Cafes' on conflict do nothing;
-- the label is unique across the whole library, not per category
insert into keywords (category_id, label)
  select id, 'tasty food' from categories where name = 'Retail' on conflict do nothing;
do $$ begin
  assert (select c from _seed_counts) = (select count(*) from categories), 'seed re-run added a category';
  assert (select s from _seed_counts) = (select count(*) from subcategories), 'seed re-run added a subcategory';
  assert (select k from _seed_counts) = (select count(*) from keywords), 'seed re-run added a keyword';
end $$;

\echo '--- prune empty categories: category without subcategories goes, its keywords become General'
insert into categories (name) values ('Empty cat');
insert into keywords (category_id, label)
  select id, 'empty cat keyword' from categories where name = 'Empty cat';
update keywords set category_id = null
where category_id in (
  select c.id from categories c
  where not exists (select 1 from subcategories s where s.category_id = c.id)
);
delete from categories c
where not exists (select 1 from subcategories s where s.category_id = c.id);
do $$ begin
  assert not exists (select 1 from categories where name = 'Empty cat'), 'empty category deleted';
  assert exists (select 1 from keywords where label = 'empty cat keyword' and category_id is null), 'keyword kept as General';
  assert (select count(*) from categories) = 8, 'seeded categories intact, got ' || (select count(*) from categories);
  assert (select count(*) from subcategories) = 29, 'subcategories intact, got ' || (select count(*) from subcategories);
end $$;
delete from keywords where label = 'empty cat keyword';

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
-- Library fixtures: 11 active keywords (one more than the cap) + 1 archived. Cafe category
-- except Fabric (Boutique) and Wifi (General). Branch picks are made below via set_branch_keywords.
insert into keywords (id, category_id, label, sort_order, is_active) values
  ('60000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Coffee', 1, true),
  ('60000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Ambience', 2, true),
  ('60000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'Staff', 3, true),
  ('60000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'Old menu', 4, false),
  ('60000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000001', 'Seating', 5, true),
  ('60000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000001', 'Music', 6, true),
  ('60000000-0000-0000-0000-000000000009', null, 'Wifi', 7, true),
  ('60000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000001', 'Cleanliness', 8, true),
  ('60000000-0000-0000-0000-00000000000b', '10000000-0000-0000-0000-000000000001', 'Pastries', 9, true),
  ('60000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000001', 'Location', 10, true),
  ('60000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000002', 'Fabric', 1, true),
  ('60000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001', 'Tea', 11, true);
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

\echo '--- set_branch_keywords: super admin, replace, ordering, duplicates, cap, unknown/archived'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_branch_keywords('30000000-0000-0000-0000-000000000001',
    array['60000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000001']::uuid[]);
  assert (select array_agg(keyword_id order by position) from branch_keywords
          where branch_id = '30000000-0000-0000-0000-000000000001')
         = array['60000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000001']::uuid[], 'first set';
  -- replaces the previous picks; duplicates merged at their first position; positions 1..n
  perform set_branch_keywords('30000000-0000-0000-0000-000000000001',
    array['60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000001',
          '60000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000002',
          '60000000-0000-0000-0000-000000000007']::uuid[]);
  assert (select array_agg(keyword_id order by position) from branch_keywords
          where branch_id = '30000000-0000-0000-0000-000000000001')
         = array['60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000001',
                 '60000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000007']::uuid[],
         'replaced, deduped, in picked order';
  assert (select array_agg(position order by position) from branch_keywords
          where branch_id = '30000000-0000-0000-0000-000000000001') = array[1, 2, 3, 4], 'positions 1..n';
  -- null = empty
  perform set_branch_keywords('30000000-0000-0000-0000-000000000002',
    array['60000000-0000-0000-0000-000000000006']::uuid[]);
  perform set_branch_keywords('30000000-0000-0000-0000-000000000002', null);
  assert not exists (select 1 from branch_keywords where branch_id = '30000000-0000-0000-0000-000000000002'), 'null clears';
  perform set_branch_keywords('30000000-0000-0000-0000-000000000002',
    array['60000000-0000-0000-0000-000000000005']::uuid[]);

  begin perform set_branch_keywords('30000000-0000-0000-0000-000000000001',
    (select array_agg(id) from keywords where id::text like '60000000-%' and is_active));
    raise exception 'FAIL 11 keywords'; exception when sqlstate '22023' then
      assert sqlerrm = 'too many keywords', 'too many message, got ' || sqlerrm; end;
  begin perform set_branch_keywords('30000000-0000-0000-0000-000000000001',
    array['60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000004']::uuid[]);
    raise exception 'FAIL archived keyword'; exception when sqlstate '22023' then
      assert sqlerrm = 'unknown keyword', 'unknown message, got ' || sqlerrm; end;
  begin perform set_branch_keywords('30000000-0000-0000-0000-000000000001', array[gen_random_uuid()]);
    raise exception 'FAIL random keyword id'; exception when sqlstate '22023' then null; end;
  begin perform set_branch_keywords('30000000-0000-0000-0000-000000000001', array[null]::uuid[]);
    raise exception 'FAIL null keyword id'; exception when sqlstate '22023' then null; end;
  begin perform set_branch_keywords(gen_random_uuid(), '{}'::uuid[]);
    raise exception 'FAIL unknown branch'; exception when sqlstate 'P0002' then null; end;
  assert (select count(*) from branch_keywords where branch_id = '30000000-0000-0000-0000-000000000001') = 4,
    'rejected calls leave the picks unchanged';

  -- no direct writes, even for super admin
  begin insert into branch_keywords values ('30000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000008', 9);
    raise exception 'FAIL super insert branch_keywords'; exception when insufficient_privilege then null; end;
  begin update branch_keywords set position = 9; raise exception 'FAIL super update branch_keywords';
  exception when insufficient_privilege then null; end;
  begin delete from branch_keywords; raise exception 'FAIL super delete branch_keywords';
  exception when insufficient_privilege then null; end;
  assert (select count(*) from branch_keywords) = 5, 'super sees all picks';
end $$;
reset role;

\echo '--- set_branch_keywords: business admin own branch only; no direct writes'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$ begin
  perform set_branch_keywords('30000000-0000-0000-0000-000000000001',
    array['60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000001',
          '60000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000007']::uuid[]);
  assert (select count(*) from branch_keywords) = 4, 'BA1 sees only own branch picks';
  assert not exists (select 1 from branch_keywords where branch_id <> '30000000-0000-0000-0000-000000000001'), 'BA1 own rows only';
  begin perform set_branch_keywords('30000000-0000-0000-0000-000000000002',
    array['60000000-0000-0000-0000-000000000001']::uuid[]);
    raise exception 'FAIL BA other company branch'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
  begin insert into branch_keywords values ('30000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000008', 9);
    raise exception 'FAIL BA insert branch_keywords'; exception when insufficient_privilege then null; end;
  begin update branch_keywords set position = 9; raise exception 'FAIL BA update branch_keywords';
  exception when insufficient_privilege then null; end;
  begin delete from branch_keywords; raise exception 'FAIL BA delete branch_keywords';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'authenticated');
do $$ begin
  assert (select count(*) from branch_keywords) = 1, 'BA2 sees only own branch picks';
  assert (select keyword_id from branch_keywords) = '60000000-0000-0000-0000-000000000005', 'BA2 pick';
  begin perform set_branch_keywords('30000000-0000-0000-0000-000000000001', '{}'::uuid[]);
    raise exception 'FAIL BA2 clears other company branch'; exception when sqlstate '42501' then null; end;
end $$;
reset role;
do $$ begin
  assert (select count(*) from branch_keywords) = 5, 'forbidden calls changed nothing';
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
  begin insert into keywords (label) values ('x');
    raise exception 'FAIL anon insert keyword';
  exception when insufficient_privilege then null; end;
  begin update keywords set label = 'x'; raise exception 'FAIL anon update keyword';
  exception when insufficient_privilege then null; end;
  begin perform 1 from branch_keywords; raise exception 'FAIL anon read branch_keywords';
  exception when insufficient_privilege then null; end;
  begin insert into branch_keywords values ('30000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000008', 9);
    raise exception 'FAIL anon insert branch_keywords';
  exception when insufficient_privilege then null; end;
  begin delete from branch_keywords; raise exception 'FAIL anon delete branch_keywords';
  exception when insufficient_privilege then null; end;
  begin perform set_branch_keywords('30000000-0000-0000-0000-000000000001', '{}'::uuid[]);
    raise exception 'FAIL anon set_branch_keywords';
  exception when insufficient_privilege then null; end;
end $$;

\echo '--- form RPC: names, the branch''s active picks in picked order, no leakage'
do $$
declare f jsonb;
begin
  f := get_feedback_form('brew1');
  assert f->>'branch_name' = 'Brew MG Road', 'branch name';
  assert f->>'company_name' = 'Brew Co', 'company name';
  assert f->>'google_place_id' = 'PLACE_BREW', 'place id';
  assert f->>'category_name' = 'Cafe', 'category name';
  assert f->>'subcategory_name' = 'Espresso bar', 'subcategory name';
  assert jsonb_array_length(f->'keywords') = 4, 'brew should have 4 picked keywords, got ' || jsonb_array_length(f->'keywords');
  assert f->'keywords'->0 = '{"id": "60000000-0000-0000-0000-000000000002", "label": "Ambience"}'::jsonb, 'first keyword is {id,label}';
  assert (select array_agg(e->>'label' order by n) from jsonb_array_elements(f->'keywords') with ordinality t(e, n))
         = array['Ambience','Coffee','Staff','Seating'],
         'ordered by picked position';
  assert not exists (select 1 from jsonb_array_elements(f->'keywords') e where e->>'label' in ('Old menu', 'Tea', 'Fabric', 'Music')),
         'no archived, unpicked or other-branch keywords';
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
    raise exception 'FAIL keyword picked for another branch'; exception when sqlstate '22023' then
      assert sqlerrm = 'unknown keyword', 'unknown message, got ' || sqlerrm; end;
  begin perform submit_feedback('brew1', 5, array['60000000-0000-0000-0000-000000000006']::uuid[], null, null);
    raise exception 'FAIL active keyword not picked for the branch'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5,
    array['60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000004']::uuid[], null, null);
    raise exception 'FAIL archived keyword'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, array[gen_random_uuid()], null, null);
    raise exception 'FAIL random keyword id'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, array[null]::uuid[], null, null);
    raise exception 'FAIL null keyword id'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, array[
      '60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003',
      '60000000-0000-0000-0000-000000000005', '60000000-0000-0000-0000-000000000006', '60000000-0000-0000-0000-000000000007',
      '60000000-0000-0000-0000-000000000008', '60000000-0000-0000-0000-000000000009', '60000000-0000-0000-0000-00000000000a',
      '60000000-0000-0000-0000-00000000000b', '60000000-0000-0000-0000-00000000000c']::uuid[], null, null);
    raise exception 'FAIL 11 keywords'; exception when sqlstate '22023' then
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

\echo '--- archived picks are hidden and rejected but kept; no picks = empty list'
update keywords set is_active = false where id = '60000000-0000-0000-0000-000000000007';
set role anon;
do $$ begin
  assert (select array_agg(e->>'label' order by n) from jsonb_array_elements(get_feedback_form('brew1')->'keywords') with ordinality t(e, n))
         = array['Ambience','Coffee','Staff'], 'archived pick hidden from form';
  begin perform submit_feedback('brew1', 5, array['60000000-0000-0000-0000-000000000007']::uuid[], null, null);
    raise exception 'FAIL archived pick'; exception when sqlstate '22023' then null; end;
end $$;
reset role;
do $$ begin
  assert exists (select 1 from branch_keywords where keyword_id = '60000000-0000-0000-0000-000000000007'), 'archiving keeps the pick row';
end $$;
update keywords set is_active = true where id = '60000000-0000-0000-0000-000000000007';
delete from branch_keywords where branch_id = '30000000-0000-0000-0000-000000000002';
set role anon;
do $$ begin
  assert get_feedback_form('silk1')->'keywords' = '[]'::jsonb, 'no picks = empty list';
end $$;
reset role;
insert into branch_keywords values ('30000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000005', 1);

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
  assert (select count(*) from keywords where category_id = '10000000-0000-0000-0000-000000000001') = 10, 'BA reads keywords';
  assert (select count(*) from keywords where category_id is null) >= 11, 'BA reads General keywords';
  begin update branches set google_place_id = 'EVIL' where true;
    assert (select count(*) from branches where google_place_id = 'EVIL') = 0, 'FAIL BA update branch';
  exception when insufficient_privilege then null; end;
  begin insert into subcategories (category_id, name) values ('10000000-0000-0000-0000-000000000001', 'x');
    raise exception 'FAIL BA insert subcategory'; exception when insufficient_privilege then null; end;
  begin insert into keywords (category_id, label) values ('10000000-0000-0000-0000-000000000001', 'x');
    raise exception 'FAIL BA insert keyword'; exception when insufficient_privilege then null; end;
  begin insert into keywords (label) values ('y');
    raise exception 'FAIL BA insert General keyword'; exception when insufficient_privilege then null; end;
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
  insert into keywords (id, category_id, label, sort_order)
    values ('60000000-0000-0000-0000-000000000099', '10000000-0000-0000-0000-000000000001', 'Beans', 12);
  update keywords set label = 'Roasted beans', category_id = null where id = '60000000-0000-0000-0000-000000000099';
  assert (select label from keywords where id = '60000000-0000-0000-0000-000000000099' and category_id is null) = 'Roasted beans',
    'super edits label and category';
  insert into keywords (label) values (repeat('x', 60));
  update subcategories set name = 'Roastery & Bar' where id = '50000000-0000-0000-0000-000000000009';
  update keywords set is_active = false where id = '60000000-0000-0000-0000-000000000099';
  assert (select name from subcategories where id = '50000000-0000-0000-0000-000000000009') = 'Roastery & Bar', 'super renames';
  assert not (select is_active from keywords where id = '60000000-0000-0000-0000-000000000099'), 'super archives';
  begin insert into keywords (category_id, label) values ('10000000-0000-0000-0000-000000000002', 'ROASTED Beans');
    raise exception 'FAIL duplicate keyword label'; exception when unique_violation then null; end;
  begin insert into keywords (label) values ('Value For Money');
    raise exception 'FAIL duplicate seed label'; exception when unique_violation then null; end;
  begin insert into keywords (label) values (repeat('x', 61));
    raise exception 'FAIL 61-char label'; exception when check_violation then null; end;
  begin insert into keywords (label) values ('');
    raise exception 'FAIL empty label'; exception when check_violation then null; end;
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

-- Company keyword fixtures are added only here so the company/branch/feedback counts asserted
-- above stay as they were. Leaf Co: leaf1 has no branch picks (inherits), leaf2 gets its own.
insert into companies (id, name, subcategory_id) values
  ('20000000-0000-0000-0000-000000000003', 'Leaf Co', '50000000-0000-0000-0000-000000000003');
insert into branches (id, company_id, name, slug, google_place_id) values
  ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 'Leaf Main', 'leaf1', 'PLACE_LEAF1'),
  ('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000003', 'Leaf Annex', 'leaf2', 'PLACE_LEAF2');

\echo '--- set_company_keywords: super admin, replace, ordering, duplicates, cap, unknown/archived'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  -- duplicates merged at their first position; positions 1..n
  perform set_company_keywords('20000000-0000-0000-0000-000000000003',
    array['60000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000001',
          '60000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000009']::uuid[]);
  assert (select array_agg(keyword_id order by position) from company_keywords
          where company_id = '20000000-0000-0000-0000-000000000003')
         = array['60000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000001',
                 '60000000-0000-0000-0000-000000000009']::uuid[], 'first set, deduped, in picked order';
  -- replaces the previous picks
  perform set_company_keywords('20000000-0000-0000-0000-000000000003',
    array['60000000-0000-0000-0000-000000000006', '60000000-0000-0000-0000-000000000001',
          '60000000-0000-0000-0000-000000000007']::uuid[]);
  assert (select array_agg(keyword_id order by position) from company_keywords
          where company_id = '20000000-0000-0000-0000-000000000003')
         = array['60000000-0000-0000-0000-000000000006', '60000000-0000-0000-0000-000000000001',
                 '60000000-0000-0000-0000-000000000007']::uuid[], 'replaced, in picked order';
  assert (select array_agg(position order by position) from company_keywords
          where company_id = '20000000-0000-0000-0000-000000000003') = array[1, 2, 3], 'positions 1..n';
  -- null = empty
  perform set_company_keywords('20000000-0000-0000-0000-000000000002',
    array['60000000-0000-0000-0000-000000000005']::uuid[]);
  perform set_company_keywords('20000000-0000-0000-0000-000000000002', null);
  assert not exists (select 1 from company_keywords where company_id = '20000000-0000-0000-0000-000000000002'), 'null clears';

  begin perform set_company_keywords('20000000-0000-0000-0000-000000000003', array[
      '60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003',
      '60000000-0000-0000-0000-000000000005', '60000000-0000-0000-0000-000000000006', '60000000-0000-0000-0000-000000000007',
      '60000000-0000-0000-0000-000000000008', '60000000-0000-0000-0000-000000000009', '60000000-0000-0000-0000-00000000000a',
      '60000000-0000-0000-0000-00000000000b', '60000000-0000-0000-0000-00000000000c']::uuid[]);
    raise exception 'FAIL company 11 keywords'; exception when sqlstate '22023' then
      assert sqlerrm = 'too many keywords', 'too many message, got ' || sqlerrm; end;
  begin perform set_company_keywords('20000000-0000-0000-0000-000000000003',
    array['60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000004']::uuid[]);
    raise exception 'FAIL company archived keyword'; exception when sqlstate '22023' then
      assert sqlerrm = 'unknown keyword', 'unknown message, got ' || sqlerrm; end;
  begin perform set_company_keywords('20000000-0000-0000-0000-000000000003', array[gen_random_uuid()]);
    raise exception 'FAIL company random keyword id'; exception when sqlstate '22023' then null; end;
  begin perform set_company_keywords('20000000-0000-0000-0000-000000000003', array[null]::uuid[]);
    raise exception 'FAIL company null keyword id'; exception when sqlstate '22023' then null; end;
  begin perform set_company_keywords(gen_random_uuid(), '{}'::uuid[]);
    raise exception 'FAIL unknown company'; exception when sqlstate 'P0002' then
      assert sqlerrm = 'unknown company', 'unknown company message, got ' || sqlerrm; end;
  assert (select count(*) from company_keywords where company_id = '20000000-0000-0000-0000-000000000003') = 3,
    'rejected calls leave the company picks unchanged';

  -- no direct writes, even for super admin
  begin insert into company_keywords values ('20000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000008', 9);
    raise exception 'FAIL super insert company_keywords'; exception when insufficient_privilege then null; end;
  begin update company_keywords set position = 9; raise exception 'FAIL super update company_keywords';
  exception when insufficient_privilege then null; end;
  begin delete from company_keywords; raise exception 'FAIL super delete company_keywords';
  exception when insufficient_privilege then null; end;

  -- leaf2 gets its own pick (override)
  perform set_branch_keywords('30000000-0000-0000-0000-000000000004',
    array['60000000-0000-0000-0000-000000000008']::uuid[]);
end $$;
reset role;

\echo '--- set_company_keywords: business admin own company only; no direct writes'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$ begin
  perform set_company_keywords('20000000-0000-0000-0000-000000000001',
    array['60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000009']::uuid[]);
  assert (select count(*) from company_keywords) = 2, 'BA1 sees only own company picks';
  assert not exists (select 1 from company_keywords where company_id <> '20000000-0000-0000-0000-000000000001'),
    'BA1 own company rows only';
  begin perform set_company_keywords('20000000-0000-0000-0000-000000000003',
    array['60000000-0000-0000-0000-000000000001']::uuid[]);
    raise exception 'FAIL BA other company keywords'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
  begin perform set_company_keywords('20000000-0000-0000-0000-000000000002', '{}'::uuid[]);
    raise exception 'FAIL BA clears other company keywords'; exception when sqlstate '42501' then null; end;
  begin insert into company_keywords values ('20000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000008', 9);
    raise exception 'FAIL BA insert company_keywords'; exception when insufficient_privilege then null; end;
  begin update company_keywords set position = 9; raise exception 'FAIL BA update company_keywords';
  exception when insufficient_privilege then null; end;
  begin delete from company_keywords; raise exception 'FAIL BA delete company_keywords';
  exception when insufficient_privilege then null; end;
  begin perform * from effective_keyword_ids('30000000-0000-0000-0000-000000000001');
    raise exception 'FAIL authenticated effective_keyword_ids'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'authenticated');
do $$ begin
  assert (select count(*) from company_keywords) = 0, 'BA2 sees no other company picks';
  begin perform set_company_keywords('20000000-0000-0000-0000-000000000001', '{}'::uuid[]);
    raise exception 'FAIL BA2 clears other company keywords'; exception when sqlstate '42501' then null; end;
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  assert (select count(*) from company_keywords) = 5, 'super sees all company picks; forbidden calls changed nothing';
end $$;
reset role;

\echo '--- anon cannot read or write company_keywords or call the keyword RPCs'
set role anon;
do $$ begin
  begin perform 1 from company_keywords; raise exception 'FAIL anon read company_keywords';
  exception when insufficient_privilege then null; end;
  begin insert into company_keywords values ('20000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000008', 9);
    raise exception 'FAIL anon insert company_keywords';
  exception when insufficient_privilege then null; end;
  begin update company_keywords set position = 9; raise exception 'FAIL anon update company_keywords';
  exception when insufficient_privilege then null; end;
  begin delete from company_keywords; raise exception 'FAIL anon delete company_keywords';
  exception when insufficient_privilege then null; end;
  begin perform set_company_keywords('20000000-0000-0000-0000-000000000001', '{}'::uuid[]);
    raise exception 'FAIL anon set_company_keywords';
  exception when insufficient_privilege then null; end;
  begin perform * from effective_keyword_ids('30000000-0000-0000-0000-000000000001');
    raise exception 'FAIL anon effective_keyword_ids';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

\echo '--- effective keywords: branch override wins, zero branch rows inherit; submit uses the effective set'
set role anon;
do $$
declare id uuid;
begin
  assert (select array_agg(e->>'label' order by n) from jsonb_array_elements(get_feedback_form('leaf1')->'keywords') with ordinality t(e, n))
         = array['Tea','Coffee','Seating'], 'leaf1 (no branch picks) inherits the company list in company order';
  assert get_feedback_form('leaf1')->'keywords'->0 = '{"id": "60000000-0000-0000-0000-000000000006", "label": "Tea"}'::jsonb,
    'inherited keyword is {id,label}';
  assert get_feedback_form('leaf2')->'keywords' = '[{"id": "60000000-0000-0000-0000-000000000008", "label": "Music"}]'::jsonb,
    'leaf2 branch picks override the company list';
  assert (select array_agg(e->>'label' order by n) from jsonb_array_elements(get_feedback_form('brew1')->'keywords') with ordinality t(e, n))
         = array['Ambience','Coffee','Staff','Seating'], 'brew1 picks override Brew Co company keywords';

  id := submit_feedback('leaf1', 4,
    array['60000000-0000-0000-0000-000000000006', '60000000-0000-0000-0000-000000000001']::uuid[], null, null);
  assert id is not null, 'inherited keywords accepted';
  begin perform submit_feedback('leaf1', 5, array['60000000-0000-0000-0000-000000000008']::uuid[], null, null);
    raise exception 'FAIL leaf1 keyword picked only for leaf2'; exception when sqlstate '22023' then
      assert sqlerrm = 'unknown keyword', 'unknown message, got ' || sqlerrm; end;
  begin perform submit_feedback('leaf2', 5, array['60000000-0000-0000-0000-000000000006']::uuid[], null, null);
    raise exception 'FAIL leaf2 company keyword while branch overrides'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, array['60000000-0000-0000-0000-000000000009']::uuid[], null, null);
    raise exception 'FAIL brew1 company keyword while branch overrides'; exception when sqlstate '22023' then null; end;
end $$;
reset role;
do $$ begin
  assert (select keywords from feedback_submissions where branch_id = '30000000-0000-0000-0000-000000000003') =
    '[{"id": "60000000-0000-0000-0000-000000000006", "label": "Tea"},
      {"id": "60000000-0000-0000-0000-000000000001", "label": "Coffee"}]'::jsonb, 'inherited snapshot in submitted order';
  assert (select count(*) from feedback_submissions where company_id = '20000000-0000-0000-0000-000000000003') = 1,
    'rejected submits stored nothing';
end $$;

-- clearing a branch's picks makes it inherit again
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_branch_keywords('30000000-0000-0000-0000-000000000004', '{}'::uuid[]);
end $$;
reset role;
set role anon;
do $$ begin
  assert (select array_agg(e->>'label' order by n) from jsonb_array_elements(get_feedback_form('leaf2')->'keywords') with ordinality t(e, n))
         = array['Tea','Coffee','Seating'], 'leaf2 with zero branch rows inherits the company list';
  perform submit_feedback('leaf2', 5, array['60000000-0000-0000-0000-000000000006']::uuid[], null, null);
  begin perform submit_feedback('leaf2', 5, array['60000000-0000-0000-0000-000000000008']::uuid[], null, null);
    raise exception 'FAIL leaf2 old branch pick after clearing'; exception when sqlstate '22023' then null; end;
end $$;
reset role;

\echo '--- effective keywords: archived company keyword hidden and rejected but kept; none at either level = []'
update keywords set is_active = false where id = '60000000-0000-0000-0000-000000000007';
set role anon;
do $$ begin
  assert (select array_agg(e->>'label' order by n) from jsonb_array_elements(get_feedback_form('leaf1')->'keywords') with ordinality t(e, n))
         = array['Tea','Coffee'], 'archived company keyword hidden from form';
  begin perform submit_feedback('leaf1', 5, array['60000000-0000-0000-0000-000000000007']::uuid[], null, null);
    raise exception 'FAIL archived company keyword'; exception when sqlstate '22023' then null; end;
end $$;
reset role;
do $$ begin
  assert exists (select 1 from company_keywords where keyword_id = '60000000-0000-0000-0000-000000000007'),
    'archiving keeps the company pick row';
end $$;
update keywords set is_active = true where id = '60000000-0000-0000-0000-000000000007';
-- Silk House has no company keywords (cleared above); with its branch pick removed, silk1 has none at either level
delete from branch_keywords where branch_id = '30000000-0000-0000-0000-000000000002';
set role anon;
do $$ begin
  assert get_feedback_form('silk1')->'keywords' = '[]'::jsonb, 'no picks at either level = empty list';
  begin perform submit_feedback('silk1', 5, array['60000000-0000-0000-0000-000000000005']::uuid[], null, null);
    raise exception 'FAIL silk1 keyword with no picks at either level'; exception when sqlstate '22023' then null; end;
end $$;
reset role;
insert into branch_keywords values ('30000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000005', 1);

\echo '--- ai: tables closed to every client role; form flag off by default'
-- run every direct read/write on the AI tables as the given role; each must be refused
create function pg_temp.check_ai_closed(u text, r text) returns void language plpgsql as $$
declare q text;
begin
  perform set_config('request.jwt.claim.sub', u, true);
  execute format('set local role %I', r);
  foreach q in array array[
    'select 1 from public.ai_settings',
    'insert into public.ai_settings (id) values (true)',
    'update public.ai_settings set is_enabled = true',
    'delete from public.ai_settings',
    'select 1 from public.ai_providers',
    'insert into public.ai_providers (provider, model) values (''gemini'', ''x'')',
    'update public.ai_providers set model = ''x''',
    'delete from public.ai_providers',
    'select 1 from public.ai_generation_log',
    'insert into public.ai_generation_log (branch_id, client_hash) values (''30000000-0000-0000-0000-000000000001'', ''x'')',
    'update public.ai_generation_log set client_hash = ''x''',
    'delete from public.ai_generation_log'
  ] loop
    begin execute q; raise exception 'FAIL % direct access: %', r, q;
    exception when insufficient_privilege then null; end;
  end loop;
  reset role;
end $$;
select pg_temp.check_ai_closed('', 'anon');
select pg_temp.check_ai_closed('00000000-0000-0000-0000-0000000000a1', 'authenticated');
select pg_temp.check_ai_closed('00000000-0000-0000-0000-0000000000b1', 'authenticated');
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'false'::jsonb, 'ai_enabled false by default';
end $$;
reset role;

\echo '--- ai admin RPCs: business admin and anon are forbidden'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$ begin
  begin perform set_ai_provider('gemini', 'gemini-2.5-flash', null, 'test-key-1234');
    raise exception 'FAIL BA set_ai_provider'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
  begin perform clear_ai_provider_key('gemini');
    raise exception 'FAIL BA clear_ai_provider_key'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
  begin perform set_ai_settings('gemini', false, 100);
    raise exception 'FAIL BA set_ai_settings'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
  begin perform get_ai_settings();
    raise exception 'FAIL BA get_ai_settings'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
end $$;
reset role;
set role anon;
do $$ begin
  begin perform set_ai_provider('gemini', 'gemini-2.5-flash', null, 'test-key-1234');
    raise exception 'FAIL anon set_ai_provider'; exception when sqlstate '42501' then null; end;
  begin perform clear_ai_provider_key('gemini');
    raise exception 'FAIL anon clear_ai_provider_key'; exception when sqlstate '42501' then null; end;
  begin perform set_ai_settings('gemini', false, 100);
    raise exception 'FAIL anon set_ai_settings'; exception when sqlstate '42501' then null; end;
  begin perform get_ai_settings();
    raise exception 'FAIL anon get_ai_settings'; exception when sqlstate '42501' then null; end;
end $$;
reset role;
do $$ begin
  assert not exists (select 1 from ai_providers), 'forbidden calls saved nothing';
  assert not exists (select 1 from vault.secrets), 'forbidden calls stored no secret';
end $$;

\echo '--- ai admin RPCs: super admin saves a provider; key is write-only'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare s jsonb;
begin
  s := get_ai_settings();
  assert s->'active_provider' = 'null'::jsonb, 'no active provider by default';
  assert s->'is_enabled' = 'false'::jsonb, 'disabled by default';
  assert (s->>'daily_limit')::int = 2000, 'default daily limit';
  assert s->'providers' = '[]'::jsonb, 'no providers by default';
  begin perform set_ai_settings('gemini', true, 2000);
    raise exception 'FAIL enable without provider'; exception when sqlstate '22023' then
      assert sqlerrm = 'provider has no key', 'no key message, got ' || sqlerrm; end;
  -- saved without a key
  perform set_ai_provider('gemini', 'gemini-2.5-flash', null);
  s := get_ai_settings()->'providers'->0;
  assert s->>'provider' = 'gemini' and s->>'model' = 'gemini-2.5-flash', 'provider saved';
  assert s->'has_key' = 'false'::jsonb and s->'key_hint' = 'null'::jsonb, 'no key yet';
  begin perform set_ai_settings('gemini', true, 2000);
    raise exception 'FAIL enable provider without key'; exception when sqlstate '22023' then
      assert sqlerrm = 'provider has no key', 'no key message, got ' || sqlerrm; end;
  -- first key
  perform set_ai_provider('gemini', 'gemini-2.5-flash', null, 'test-key-1234');
  s := get_ai_settings()->'providers'->0;
  assert s->'has_key' = 'true'::jsonb, 'has key';
  assert s->>'key_hint' = '1234', 'key hint is the last 4 characters';
end $$;
reset role;
do $$ begin
  assert (select count(*) from vault.secrets where name = 'ai_key_gemini') = 1, 'one vault secret for gemini';
  assert (select d.decrypted_secret from ai_providers p join vault.decrypted_secrets d on d.id = p.secret_id
          where p.provider = 'gemini') = 'test-key-1234', 'key stored in vault';
  assert (select key_hint from ai_providers where provider = 'gemini') = '1234', 'table keeps only the hint';
  insert into _ids select 'gemini_secret', secret_id from ai_providers where provider = 'gemini';
end $$;

\echo '--- ai admin RPCs: null key keeps the key, a new key replaces it; output never has the key'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare s jsonb;
begin
  perform set_ai_provider('gemini', 'gemini-2.5-pro', null, null);
  perform set_ai_provider('gemini', 'gemini-2.5-pro', '', '');
  s := get_ai_settings()->'providers'->0;
  assert s->>'model' = 'gemini-2.5-pro', 'model updated';
  assert s->'has_key' = 'true'::jsonb and s->>'key_hint' = '1234', 'null/empty key keeps the key';
end $$;
reset role;
do $$ begin
  assert (select secret_id from ai_providers where provider = 'gemini') = (select v from _ids where k = 'gemini_secret'),
    'same secret kept';
  assert (select decrypted_secret from vault.decrypted_secrets where name = 'ai_key_gemini') = 'test-key-1234',
    'key unchanged';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare s jsonb;
begin
  perform set_ai_provider('gemini', 'gemini-2.5-pro', null, 'test-key-5678');
  s := get_ai_settings();
  assert s->'providers'->0->>'key_hint' = '5678', 'new key updates the hint';
  assert position('test-key' in s::text) = 0, 'settings output has no key';
  assert position((select v::text from _ids where k = 'gemini_secret') in s::text) = 0, 'settings output has no secret id';
  assert not (s->'providers'->0 ? 'secret_id') and not (s->'providers'->0 ? 'api_key'), 'no secret fields';
end $$;
reset role;
do $$ begin
  assert (select secret_id from ai_providers where provider = 'gemini') = (select v from _ids where k = 'gemini_secret'),
    'replacement updates the same vault secret';
  assert (select decrypted_secret from vault.decrypted_secrets where name = 'ai_key_gemini') = 'test-key-5678',
    'key replaced';
  assert (select count(*) from vault.secrets) = 1, 'no extra vault secret';
end $$;

\echo '--- ai admin RPCs: input validation and the base URL guard'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare u text;
begin
  begin perform set_ai_provider('bogus', 'm', null, null);
    raise exception 'FAIL bogus provider'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_provider('gemini', '', null, null);
    raise exception 'FAIL empty model'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_provider('gemini', repeat('m', 101), null, null);
    raise exception 'FAIL 101-char model'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_provider('gemini', 'gemini-2.5-pro', 'https://api.example.com', null);
    raise exception 'FAIL gemini base url'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_provider('anthropic', 'claude-haiku-5-5', 'https://api.example.com', null);
    raise exception 'FAIL anthropic base url'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_provider('gemini', 'gemini-2.5-pro', null, 'short');
    raise exception 'FAIL short key'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_provider('gemini', 'gemini-2.5-pro', null, 'test key 1234');
    raise exception 'FAIL key with spaces'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_provider('gemini', 'gemini-2.5-pro', null, 'test-key-' || repeat('x', 392));
    raise exception 'FAIL 401-char key'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_provider('custom', 'my-model', null, 'test-key-9999');
    raise exception 'FAIL custom without base url'; exception when sqlstate '22023' then
      assert sqlerrm = 'invalid base url', 'base url message, got ' || sqlerrm; end;
  foreach u in array array[
    'http://api.example.com/v1',
    'https://localhost/v1',
    'https://LOCALHOST:8080/v1',
    'https://127.0.0.1/v1',
    'https://[::1]/v1',
    'https://llm.corp.internal/v1',
    'https://printer.local/v1',
    'https://user:pass@api.example.com/v1',
    'https://api.example.com/v1?x=1',
    'https://' || repeat('a', 300) || '.com'
  ] loop
    begin perform set_ai_provider('custom', 'my-model', u, 'test-key-9999');
      raise exception 'FAIL custom base url %', u; exception when sqlstate '22023' then
        assert sqlerrm = 'invalid base url', 'base url message for ' || u || ', got ' || sqlerrm; end;
  end loop;
  assert jsonb_array_length(get_ai_settings()->'providers') = 1, 'rejected calls saved nothing';
  assert (get_ai_settings()->'providers'->0->>'key_hint') = '5678', 'rejected calls kept the key';

  -- valid custom and openai; trailing slash stripped
  perform set_ai_provider('custom', 'my-model', 'https://api.example.com/v1/', 'test-key-9999');
  perform set_ai_provider('openai', 'gpt-4o-mini', null, null);
  perform set_ai_provider('openai', 'gpt-4o-mini', 'https://api.openai.com/v1', null);
  assert (select e->>'base_url' from jsonb_array_elements(get_ai_settings()->'providers') e
          where e->>'provider' = 'custom') = 'https://api.example.com/v1', 'custom base url saved without trailing slash';
  assert (select e->'has_key' from jsonb_array_elements(get_ai_settings()->'providers') e
          where e->>'provider' = 'openai') = 'false'::jsonb, 'openai saved without a key';
  assert jsonb_array_length(get_ai_settings()->'providers') = 3, 'three providers saved';
end $$;
reset role;

\echo '--- ai settings: validation, enable needs a key, clearing the key disables'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare s jsonb;
begin
  begin perform set_ai_settings('bogus', false, 100);
    raise exception 'FAIL bogus active provider'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_settings('gemini', false, 0);
    raise exception 'FAIL daily limit 0'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_settings('gemini', false, 100001);
    raise exception 'FAIL daily limit 100001'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_settings('gemini', false, null);
    raise exception 'FAIL daily limit null'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_settings('openai', true, 100);
    raise exception 'FAIL enable openai without key'; exception when sqlstate '22023' then
      assert sqlerrm = 'provider has no key', 'no key message, got ' || sqlerrm; end;
  begin perform set_ai_settings(null, true, 100);
    raise exception 'FAIL enable without active provider'; exception when sqlstate '22023' then null; end;
  perform set_ai_settings('gemini', true, 2000);
  s := get_ai_settings();
  assert s->>'active_provider' = 'gemini' and s->'is_enabled' = 'true'::jsonb, 'enabled with a key';
end $$;
reset role;
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'true'::jsonb, 'ai_enabled true once enabled with a key';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare s jsonb;
begin
  perform clear_ai_provider_key('gemini');
  s := get_ai_settings();
  assert s->'is_enabled' = 'false'::jsonb, 'clearing the active key disables';
  assert s->>'active_provider' = 'gemini', 'active provider kept';
  assert (select e->'has_key' from jsonb_array_elements(s->'providers') e where e->>'provider' = 'gemini') = 'false'::jsonb,
    'gemini key cleared';
  assert (select e->'key_hint' from jsonb_array_elements(s->'providers') e where e->>'provider' = 'gemini') = 'null'::jsonb,
    'gemini hint cleared';
end $$;
reset role;
do $$ begin
  assert not exists (select 1 from vault.secrets where name = 'ai_key_gemini'), 'vault secret deleted';
  assert (select secret_id from ai_providers where provider = 'gemini') is null, 'secret id cleared';
  assert exists (select 1 from vault.secrets where name = 'ai_key_custom'), 'other provider key kept';
end $$;
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'false'::jsonb, 'ai_enabled false after the key is cleared';
end $$;
reset role;
-- a fresh gemini key, saved but not enabled yet
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_provider('gemini', 'gemini-2.5-pro', null, 'test-key-1234');
end $$;
reset role;

\echo '--- ai runtime RPCs: not executable by anon or authenticated (even super admin)'
create function pg_temp.check_ai_runtime_closed(u text, r text) returns void language plpgsql as $$
declare q text;
begin
  perform set_config('request.jwt.claim.sub', u, true);
  execute format('set local role %I', r);
  foreach q in array array[
    'select public.get_ai_runtime()',
    'select public.get_ai_provider_runtime(''gemini'')',
    'select public.get_review_context(''brew1'', ''{}''::uuid[])',
    'select public.log_ai_generation(''30000000-0000-0000-0000-000000000001'', ''x'')',
    'select public.ai_valid_base_url(''https://api.example.com'')'
  ] loop
    begin execute q; raise exception 'FAIL % runtime call: %', r, q;
    exception when insufficient_privilege then null; end;
  end loop;
  reset role;
end $$;
select pg_temp.check_ai_runtime_closed('', 'anon');
select pg_temp.check_ai_runtime_closed('00000000-0000-0000-0000-0000000000a1', 'authenticated');
select pg_temp.check_ai_runtime_closed('00000000-0000-0000-0000-0000000000b1', 'authenticated');

\echo '--- ai runtime RPCs: service role reads the key only when enabled / for a provider with a key'
set role service_role;
do $$
declare r jsonb;
begin
  assert get_ai_runtime() is null, 'disabled = no runtime';
  r := get_ai_provider_runtime('gemini');
  assert r->>'provider' = 'gemini' and r->>'model' = 'gemini-2.5-pro', 'gemini runtime';
  assert r->>'api_key' = 'test-key-1234', 'gemini runtime key';
  assert r->'base_url' = 'null'::jsonb and (r->>'daily_limit')::int = 2000, 'gemini runtime base url and limit';
  r := get_ai_provider_runtime('custom');
  assert r->>'api_key' = 'test-key-9999' and r->>'base_url' = 'https://api.example.com/v1', 'custom runtime';
  assert get_ai_provider_runtime('openai') is null, 'provider without a key = null';
  assert get_ai_provider_runtime('anthropic') is null, 'unsaved provider = null';
  assert get_ai_provider_runtime('bogus') is null, 'unknown provider = null';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_settings('gemini', true, 2000);
end $$;
reset role;
set role service_role;
do $$
declare r jsonb;
begin
  r := get_ai_runtime();
  assert r->>'provider' = 'gemini' and r->>'model' = 'gemini-2.5-pro', 'enabled runtime provider';
  assert r->>'api_key' = 'test-key-1234' and (r->>'daily_limit')::int = 2000, 'enabled runtime key and limit';
end $$;
reset role;

\echo '--- get_review_context: valid, inherited, unknown slug, outside the effective set, more than 10'
set role service_role;
do $$
declare r jsonb;
begin
  r := get_review_context('brew1', array['60000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000002',
                                          '60000000-0000-0000-0000-000000000003']::uuid[]);
  assert r->>'branch_id' = '30000000-0000-0000-0000-000000000001', 'branch id';
  assert r->>'company_name' = 'Brew Co' and r->>'branch_name' = 'Brew MG Road', 'names';
  assert r->>'category_name' = 'Cafe' and r->>'subcategory_name' = 'Espresso bar', 'taxonomy names';
  assert r->'labels' = '["Staff", "Ambience"]'::jsonb, 'labels in request order, duplicates merged, got ' || (r->'labels')::text;
  assert get_review_context('leaf1', array['60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000006']::uuid[])->'labels'
         = '["Coffee", "Tea"]'::jsonb, 'inherited company keywords accepted';
  assert get_review_context('brew1', '{}'::uuid[])->'labels' = '[]'::jsonb, 'no keywords = []';
  assert get_review_context('nope', array['60000000-0000-0000-0000-000000000001']::uuid[]) is null, 'unknown slug = null';
  begin perform get_review_context('brew1', array['60000000-0000-0000-0000-000000000006']::uuid[]);
    raise exception 'FAIL keyword outside the effective set'; exception when sqlstate '22023' then
      assert sqlerrm = 'unknown keyword', 'unknown message, got ' || sqlerrm; end;
  begin perform get_review_context('brew1', array['60000000-0000-0000-0000-000000000004']::uuid[]);
    raise exception 'FAIL archived keyword'; exception when sqlstate '22023' then null; end;
  begin perform get_review_context('brew1', array[null]::uuid[]);
    raise exception 'FAIL null keyword id'; exception when sqlstate '22023' then null; end;
  begin perform get_review_context('brew1', array[
      '60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003',
      '60000000-0000-0000-0000-000000000005', '60000000-0000-0000-0000-000000000006', '60000000-0000-0000-0000-000000000007',
      '60000000-0000-0000-0000-000000000008', '60000000-0000-0000-0000-000000000009', '60000000-0000-0000-0000-00000000000a',
      '60000000-0000-0000-0000-00000000000b', '60000000-0000-0000-0000-00000000000c']::uuid[]);
    raise exception 'FAIL 11 keywords'; exception when sqlstate '22023' then null; end;
end $$;
reset role;
update branches set is_active = false where slug = 'brew1';
set role service_role;
do $$ begin
  assert get_review_context('brew1', array['60000000-0000-0000-0000-000000000002']::uuid[]) is null, 'inactive branch = null';
end $$;
reset role;
update branches set is_active = true where slug = 'brew1';
update companies set is_active = false where id = '20000000-0000-0000-0000-000000000001';
set role service_role;
do $$ begin
  assert get_review_context('brew1', array['60000000-0000-0000-0000-000000000002']::uuid[]) is null, 'inactive company = null';
end $$;
reset role;
update companies set is_active = true where id = '20000000-0000-0000-0000-000000000001';

\echo '--- log_ai_generation: 6 per client per 10 minutes, daily limit, old rows pruned'
insert into ai_generation_log (branch_id, client_hash, created_at)
  values ('30000000-0000-0000-0000-000000000001', 'hash-old', now() - interval '8 days');
set role service_role;
do $$
declare i int;
begin
  for i in 1..6 loop
    assert log_ai_generation('30000000-0000-0000-0000-000000000001', 'hash-a'), 'generation ' || i || ' allowed';
  end loop;
  assert not log_ai_generation('30000000-0000-0000-0000-000000000001', 'hash-a'), '7th for the same client refused';
  assert log_ai_generation('30000000-0000-0000-0000-000000000001', 'hash-b'), 'another client allowed';
end $$;
reset role;
do $$ begin
  assert (select count(*) from ai_generation_log) = 7, 'refused call stored nothing; old row pruned, got '
    || (select count(*) from ai_generation_log);
  assert not exists (select 1 from ai_generation_log where client_hash = 'hash-old'), 'rows older than 7 days deleted';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_settings('gemini', true, 8);
end $$;
reset role;
set role service_role;
do $$ begin
  assert log_ai_generation('30000000-0000-0000-0000-000000000002', 'hash-c'), '8th of the day allowed';
  assert not log_ai_generation('30000000-0000-0000-0000-000000000002', 'hash-d'), 'daily limit reached';
end $$;
reset role;
do $$ begin
  assert (select count(*) from ai_generation_log) = 8, 'daily limit refusal stored nothing';
end $$;

\echo '--- get_feedback_form.ai_enabled: needs enabled + a key on the active provider'
set role anon;
do $$
declare f jsonb;
begin
  f := get_feedback_form('brew1');
  assert f->'ai_enabled' = 'true'::jsonb, 'enabled with a key';
  assert f->>'branch_name' = 'Brew MG Road' and jsonb_array_length(f->'keywords') = 4, 'existing fields kept';
  assert get_feedback_form('nope') is null, 'unknown slug still null';
end $$;
reset role;
update ai_settings set active_provider = 'openai';
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'false'::jsonb, 'active provider without a key = false';
end $$;
reset role;
update ai_settings set active_provider = 'gemini';
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_settings('gemini', false, 2000);
end $$;
reset role;
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'false'::jsonb, 'disabled = false';
end $$;
reset role;

\echo '--- user without profile sees nothing'
select pg_temp.as_user('00000000-0000-0000-0000-00000000dead', 'authenticated');
do $$ begin
  assert (select count(*) from categories) = 0;
  assert (select count(*) from subcategories) = 0;
  assert (select count(*) from keywords) = 0;
  assert (select count(*) from branch_keywords) = 0;
  assert (select count(*) from company_keywords) = 0;
  assert (select count(*) from feedback_submissions) = 0;
  begin perform set_branch_keywords('30000000-0000-0000-0000-000000000001', '{}'::uuid[]);
    raise exception 'FAIL no-profile set_branch_keywords'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
  begin perform set_company_keywords('20000000-0000-0000-0000-000000000001', '{}'::uuid[]);
    raise exception 'FAIL no-profile set_company_keywords'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
end $$;
reset role;
\echo 'ALL RLS TESTS PASSED'
