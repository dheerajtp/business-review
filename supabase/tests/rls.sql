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
    'delete from public.ai_providers'
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
  begin perform set_ai_settings('gemini', false);
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
  begin perform set_ai_settings('gemini', false);
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
  assert position('daily_limit' in s::text) = 0, 'no daily_limit in get_ai_settings';
  assert s->'providers' = '[]'::jsonb, 'no providers by default';
  begin perform set_ai_settings('gemini', true);
    raise exception 'FAIL enable without provider'; exception when sqlstate '22023' then
      assert sqlerrm = 'provider has no key', 'no key message, got ' || sqlerrm; end;
  -- saved without a key
  perform set_ai_provider('gemini', 'gemini-2.5-flash', null);
  s := get_ai_settings()->'providers'->0;
  assert s->>'provider' = 'gemini' and s->>'model' = 'gemini-2.5-flash', 'provider saved';
  assert s->'has_key' = 'false'::jsonb and s->'key_hint' = 'null'::jsonb, 'no key yet';
  begin perform set_ai_settings('gemini', true);
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
  begin perform set_ai_settings('bogus', false);
    raise exception 'FAIL bogus active provider'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_settings('openai', true);
    raise exception 'FAIL enable openai without key'; exception when sqlstate '22023' then
      assert sqlerrm = 'provider has no key', 'no key message, got ' || sqlerrm; end;
  begin perform set_ai_settings(null, true);
    raise exception 'FAIL enable without active provider'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_settings('gemini', true);
    raise exception 'FAIL enable untested provider'; exception when sqlstate '22023' then
      assert sqlerrm = 'provider not tested', 'not tested message, got ' || sqlerrm; end;
end $$;
reset role;
set role service_role;
select record_ai_test('gemini', true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare s jsonb;
begin
  perform set_ai_settings('gemini', true);
  s := get_ai_settings();
  assert s->>'active_provider' = 'gemini' and s->'is_enabled' = 'true'::jsonb, 'enabled with a key and a passed test';
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
  assert r->'base_url' = 'null'::jsonb, 'gemini runtime base url';
  assert position('daily_limit' in r::text) = 0, 'no daily_limit in get_ai_provider_runtime';
  r := get_ai_provider_runtime('custom');
  assert r->>'api_key' = 'test-key-9999' and r->>'base_url' = 'https://api.example.com/v1', 'custom runtime';
  assert get_ai_provider_runtime('openai') is null, 'provider without a key = null';
  assert get_ai_provider_runtime('anthropic') is null, 'unsaved provider = null';
  assert get_ai_provider_runtime('bogus') is null, 'unknown provider = null';
end $$;
reset role;
set role service_role;
select record_ai_test('gemini', true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_settings('gemini', true);
end $$;
reset role;
set role service_role;
do $$
declare r jsonb;
begin
  r := get_ai_runtime();
  assert r->>'provider' = 'gemini' and r->>'model' = 'gemini-2.5-pro', 'enabled runtime provider';
  assert r->>'api_key' = 'test-key-1234', 'enabled runtime key';
  assert position('daily_limit' in r::text) = 0, 'no daily_limit in get_ai_runtime';
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

\echo '--- ai limits removed: log table and function gone, no daily_limit anywhere'
do $$ begin
  assert to_regclass('public.ai_generation_log') is null, 'ai_generation_log table dropped';
  assert not exists (select 1 from pg_proc where proname = 'log_ai_generation'), 'log_ai_generation dropped';
  assert not exists (select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'ai_settings' and column_name = 'daily_limit'), 'daily_limit column dropped';
  assert not exists (select 1 from pg_proc where proname = 'set_ai_settings' and pronargs = 3), 'old 3-arg set_ai_settings dropped';
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
  perform set_ai_settings('gemini', false);
end $$;
reset role;
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'false'::jsonb, 'disabled = false';
end $$;
reset role;

\echo '--- ai test gate: new columns default to untested; record_ai_test closed to anon and authenticated'
do $$ begin
  assert (select column_default from information_schema.columns
          where table_schema = 'public' and table_name = 'ai_providers' and column_name = 'last_test_ok') = 'false',
    'last_test_ok defaults to false';
  assert (select is_nullable from information_schema.columns
          where table_schema = 'public' and table_name = 'ai_providers' and column_name = 'last_tested_at') = 'YES',
    'last_tested_at is nullable';
  assert (select last_test_ok from ai_providers where provider = 'openai') = false, 'never tested provider = false';
  assert (select last_tested_at from ai_providers where provider = 'openai') is null, 'never tested provider has no time';
  assert (select last_test_ok from ai_providers where provider = 'custom') = false, 'custom starts untested';
end $$;
create function pg_temp.check_ai_test_closed(u text, r text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, true);
  execute format('set local role %I', r);
  begin perform public.record_ai_test('gemini', true); raise exception 'FAIL % record_ai_test', r;
  exception when insufficient_privilege then null; end;
  reset role;
end $$;
select pg_temp.check_ai_test_closed('', 'anon');
select pg_temp.check_ai_test_closed('00000000-0000-0000-0000-0000000000a1', 'authenticated');
select pg_temp.check_ai_test_closed('00000000-0000-0000-0000-0000000000b1', 'authenticated');

\echo '--- record_ai_test: service role records pass/fail, rejects an invalid provider, unknown row is a no-op'
set role service_role;
select record_ai_test('gemini', false);
reset role;
do $$ begin
  assert (select last_test_ok from ai_providers where provider = 'gemini') = false, 'failure recorded';
  assert (select last_tested_at from ai_providers where provider = 'gemini') is not null, 'failure time recorded';
end $$;
set role service_role;
select record_ai_test('gemini', true);
reset role;
do $$ begin
  assert (select last_test_ok from ai_providers where provider = 'gemini') = true, 'pass recorded';
end $$;
set role service_role;
select record_ai_test('gemini', null);
reset role;
do $$ begin
  assert (select last_test_ok from ai_providers where provider = 'gemini') = false, 'null result = false';
end $$;
set role service_role;
do $$ begin
  begin perform record_ai_test('bogus', true);
    raise exception 'FAIL bogus provider'; exception when sqlstate '22023' then null; end;
  begin perform record_ai_test(null, true);
    raise exception 'FAIL null provider'; exception when sqlstate '22023' then null; end;
  perform record_ai_test('anthropic', true);
end $$;
reset role;
do $$ begin
  assert not exists (select 1 from ai_providers where provider = 'anthropic'), 'unknown row = no-op, nothing created';
end $$;

\echo '--- set_ai_provider resets the test on a changed model, base URL or key; a no-op save keeps it'
set role service_role;
select record_ai_test('gemini', true);
select record_ai_test('custom', true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_provider('gemini', 'gemini-2.5-pro', null, null);
  perform set_ai_provider('gemini', 'gemini-2.5-pro', '', '');
  perform set_ai_provider('custom', 'my-model', 'https://api.example.com/v1/', null);
end $$;
reset role;
do $$ begin
  assert (select last_test_ok from ai_providers where provider = 'gemini') = true, 'no-op save keeps gemini test';
  assert (select last_tested_at from ai_providers where provider = 'gemini') is not null, 'no-op save keeps gemini time';
  assert (select last_test_ok from ai_providers where provider = 'custom') = true, 'no-op save keeps custom test';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_provider('gemini', 'gemini-2.5-flash', null, null);
  perform set_ai_provider('custom', 'my-model', 'https://api.example.org/v1', null);
end $$;
reset role;
do $$ begin
  assert (select last_test_ok from ai_providers where provider = 'gemini') = false, 'model change resets the test';
  assert (select last_tested_at from ai_providers where provider = 'gemini') is null, 'model change clears the time';
  assert (select last_test_ok from ai_providers where provider = 'custom') = false, 'base url change resets the test';
  assert (select last_tested_at from ai_providers where provider = 'custom') is null, 'base url change clears the time';
end $$;
set role service_role;
select record_ai_test('gemini', true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_provider('gemini', 'gemini-2.5-flash', null, 'test-key-4321');
end $$;
reset role;
do $$ begin
  assert (select last_test_ok from ai_providers where provider = 'gemini') = false, 'new key resets the test';
  assert (select last_tested_at from ai_providers where provider = 'gemini') is null, 'new key clears the time';
end $$;

\echo '--- clear_ai_provider_key resets the test'
set role service_role;
select record_ai_test('gemini', true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform clear_ai_provider_key('gemini');
end $$;
reset role;
do $$ begin
  assert (select last_test_ok from ai_providers where provider = 'gemini') = false, 'clearing the key resets the test';
  assert (select last_tested_at from ai_providers where provider = 'gemini') is null, 'clearing the key clears the time';
end $$;
-- a fresh gemini key, saved but untested
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_provider('gemini', 'gemini-2.5-pro', null, 'test-key-1234');
end $$;
reset role;

\echo '--- set_ai_settings: enabling needs a passed test; switching the active provider follows the same rule'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  begin perform set_ai_settings('openai', true);
    raise exception 'FAIL enable openai without key'; exception when sqlstate '22023' then
      assert sqlerrm = 'provider has no key', 'no key message comes first, got ' || sqlerrm; end;
  begin perform set_ai_settings('gemini', true);
    raise exception 'FAIL enable untested gemini'; exception when sqlstate '22023' then
      assert sqlerrm = 'provider not tested', 'not tested message, got ' || sqlerrm; end;
  assert (get_ai_settings()->'is_enabled') = 'false'::jsonb, 'rejected enable changed nothing';
end $$;
reset role;
set role service_role;
select record_ai_test('gemini', true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare s jsonb;
begin
  perform set_ai_settings('gemini', true);
  s := get_ai_settings();
  assert s->>'active_provider' = 'gemini' and s->'is_enabled' = 'true'::jsonb, 'enabled after a passed test';
  begin perform set_ai_settings('custom', true);
    raise exception 'FAIL switch to untested custom'; exception when sqlstate '22023' then
      assert sqlerrm = 'provider not tested', 'switch not tested message, got ' || sqlerrm; end;
  s := get_ai_settings();
  assert s->>'active_provider' = 'gemini' and s->'is_enabled' = 'true'::jsonb, 'rejected switch changed nothing';
end $$;
reset role;
set role service_role;
select record_ai_test('custom', true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_settings('custom', true);
  assert (get_ai_settings()->>'active_provider') = 'custom', 'switched to the tested provider';
  perform set_ai_settings('gemini', true);
  assert (get_ai_settings()->>'active_provider') = 'gemini', 'switched back';
end $$;
reset role;

\echo '--- get_feedback_form.ai_enabled: needs enabled, a key and a passed test; false again after a failed test'
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'true'::jsonb, 'enabled, keyed and tested';
end $$;
reset role;
set role service_role;
select record_ai_test('gemini', false);
reset role;
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'false'::jsonb, 'recorded failure = false while still enabled';
end $$;
reset role;
set role service_role;
select record_ai_test('gemini', true);
reset role;
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'true'::jsonb, 'recorded pass = true again';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_settings('gemini', false);
end $$;
reset role;
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'false'::jsonb, 'tested but disabled = false';
end $$;
reset role;

\echo '--- get_ai_settings: shows the test fields, still no key or secret id'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare s jsonb;
begin
  s := get_ai_settings();
  assert (select e->'last_test_ok' from jsonb_array_elements(s->'providers') e where e->>'provider' = 'gemini')
         = 'true'::jsonb, 'gemini last_test_ok true';
  assert (select e->>'last_tested_at' from jsonb_array_elements(s->'providers') e where e->>'provider' = 'gemini')
         is not null, 'gemini last_tested_at set';
  assert (select e->'last_test_ok' from jsonb_array_elements(s->'providers') e where e->>'provider' = 'openai')
         = 'false'::jsonb, 'openai last_test_ok false';
  assert (select e->'last_tested_at' from jsonb_array_elements(s->'providers') e where e->>'provider' = 'openai')
         = 'null'::jsonb, 'openai last_tested_at null';
  assert position('test-key' in s::text) = 0, 'settings output has no key';
  assert not exists (select 1 from jsonb_array_elements(s->'providers') e where e ? 'secret_id' or e ? 'api_key'),
    'no secret fields';
end $$;
reset role;

\echo '--- ai resilience: new columns default; record_ai_test is 3-arg only and service-role only'
do $$ begin
  assert (select column_default from information_schema.columns
          where table_schema = 'public' and table_name = 'ai_providers' and column_name = 'last_test_busy') = 'false',
    'last_test_busy defaults to false';
  assert (select is_nullable from information_schema.columns
          where table_schema = 'public' and table_name = 'ai_providers' and column_name = 'fallback_model') = 'YES',
    'fallback_model is nullable';
  assert (select fallback_model from ai_providers where provider = 'openai') is null, 'fallback_model defaults to null';
  assert (select last_test_busy from ai_providers where provider = 'openai') = false, 'last_test_busy defaults to false';
  assert not exists (select 1 from pg_proc where proname = 'record_ai_test' and pronargs = 2),
    'the 2-arg record_ai_test is gone';
  assert (select count(*) from pg_proc where proname = 'record_ai_test' and pronargs = 3) = 1,
    'exactly one 3-arg record_ai_test';
end $$;
create function pg_temp.check_ai_test3_closed(u text, r text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, true);
  execute format('set local role %I', r);
  begin perform public.record_ai_test('gemini', true, true); raise exception 'FAIL % record_ai_test 3-arg', r;
  exception when insufficient_privilege then null; end;
  reset role;
end $$;
select pg_temp.check_ai_test3_closed('', 'anon');
select pg_temp.check_ai_test3_closed('00000000-0000-0000-0000-0000000000a1', 'authenticated');
select pg_temp.check_ai_test3_closed('00000000-0000-0000-0000-0000000000b1', 'authenticated');

\echo '--- record_ai_test busy flag: stored only with a pass; invalid provider rejected'
set role service_role;
select record_ai_test('gemini', true, true);
reset role;
do $$ begin
  assert (select last_test_ok from ai_providers where provider = 'gemini') = true, 'busy pass is ok';
  assert (select last_test_busy from ai_providers where provider = 'gemini') = true, 'busy flag stored with a pass';
end $$;
set role service_role;
select record_ai_test('gemini', false, true);
reset role;
do $$ begin
  assert (select last_test_ok from ai_providers where provider = 'gemini') = false, 'failure recorded';
  assert (select last_test_busy from ai_providers where provider = 'gemini') = false, 'busy ignored on a failure';
end $$;
set role service_role;
select record_ai_test('gemini', null, true);
reset role;
do $$ begin
  assert (select last_test_busy from ai_providers where provider = 'gemini') = false, 'busy ignored on a null result';
end $$;
set role service_role;
select record_ai_test('gemini', true, null);
reset role;
do $$ begin
  assert (select last_test_ok from ai_providers where provider = 'gemini') = true
     and (select last_test_busy from ai_providers where provider = 'gemini') = false, 'null busy = false';
end $$;
set role service_role;
select record_ai_test('gemini', true, true);
select record_ai_test('gemini', true);
reset role;
do $$ begin
  assert (select last_test_busy from ai_providers where provider = 'gemini') = false, '2-arg call clears busy via the default';
end $$;
set role service_role;
do $$ begin
  begin perform record_ai_test('bogus', true, true);
    raise exception 'FAIL bogus provider'; exception when sqlstate '22023' then null; end;
  begin perform record_ai_test(null, true, false);
    raise exception 'FAIL null provider'; exception when sqlstate '22023' then null; end;
end $$;
reset role;

\echo '--- busy flag resets: changed model, new key and cleared key; a no-op save keeps it'
set role service_role;
select record_ai_test('gemini', true, true);
select record_ai_test('custom', true, true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_provider('gemini', 'gemini-2.5-pro', null, null);
end $$;
reset role;
do $$ begin
  assert (select last_test_busy from ai_providers where provider = 'gemini') = true, 'no-op save keeps busy';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_provider('gemini', 'gemini-2.5-flash', null, null);
end $$;
reset role;
do $$ begin
  assert (select last_test_busy from ai_providers where provider = 'gemini') = false, 'model change resets busy';
  assert (select last_test_ok from ai_providers where provider = 'gemini') = false, 'model change resets ok';
end $$;
set role service_role;
select record_ai_test('gemini', true, true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_provider('gemini', 'gemini-2.5-flash', null, 'test-key-1234');
end $$;
reset role;
do $$ begin
  assert (select last_test_busy from ai_providers where provider = 'gemini') = false, 'new key resets busy';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform clear_ai_provider_key('custom');
end $$;
reset role;
do $$ begin
  assert (select last_test_busy from ai_providers where provider = 'custom') = false, 'clearing the key resets busy';
  assert (select last_test_ok from ai_providers where provider = 'custom') = false, 'clearing the key resets ok';
end $$;
-- restore a keyed custom provider for later sections
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_provider('custom', 'my-model', 'https://api.example.org/v1', 'test-key-9999');
end $$;
reset role;

\echo '--- set_ai_settings: enabling works after a busy pass (busy is still a pass)'
set role service_role;
select record_ai_test('gemini', true, true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_settings('gemini', true);
  assert get_ai_settings()->'is_enabled' = 'true'::jsonb, 'enabled after a busy pass';
end $$;
reset role;
set role anon;
do $$ begin
  assert get_feedback_form('brew1')->'ai_enabled' = 'true'::jsonb, 'busy pass still counts as tested';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_settings('gemini', false);
end $$;
reset role;

\echo '--- set_ai_fallback_model: super admin only, validation, blank clears, needs a saved provider, keeps the test'
create function pg_temp.check_fallback_forbidden(u text, r text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, true);
  execute format('set local role %I', r);
  begin perform public.set_ai_fallback_model('gemini', 'gemini-2.0-flash'); raise exception 'FAIL % set_ai_fallback_model', r;
  exception when sqlstate '42501' then null; end;
  reset role;
end $$;
select pg_temp.check_fallback_forbidden('', 'anon');
select pg_temp.check_fallback_forbidden('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$ begin
  assert (select fallback_model from ai_providers where provider = 'gemini') is null, 'forbidden calls changed nothing';
end $$;
set role service_role;
select record_ai_test('gemini', true, true);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_fallback_model('gemini', '  gemini-2.0-flash  ');
end $$;
reset role;
do $$ begin
  assert (select fallback_model from ai_providers where provider = 'gemini') = 'gemini-2.0-flash', 'trimmed and stored';
  assert (select last_test_ok from ai_providers where provider = 'gemini') = true, 'fallback change keeps ok';
  assert (select last_test_busy from ai_providers where provider = 'gemini') = true, 'fallback change keeps busy';
  assert (select last_tested_at from ai_providers where provider = 'gemini') is not null, 'fallback change keeps the time';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  begin perform set_ai_fallback_model('bogus', 'x');
    raise exception 'FAIL bogus provider'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_fallback_model(null, 'x');
    raise exception 'FAIL null provider'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_fallback_model('gemini', repeat('m', 101));
    raise exception 'FAIL 101 characters'; exception when sqlstate '22023' then null; end;
  begin perform set_ai_fallback_model('anthropic', 'claude-x');
    raise exception 'FAIL unsaved provider'; exception when sqlstate '22023' then
      assert sqlerrm = 'save the provider first', 'unsaved provider message, got ' || sqlerrm; end;
  perform set_ai_fallback_model('gemini', repeat('m', 100));
end $$;
reset role;
do $$ begin
  assert char_length((select fallback_model from ai_providers where provider = 'gemini')) = 100, '100 characters accepted';
end $$;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_fallback_model('gemini', 'gemini-2.0-flash');
end $$;
reset role;
do $$ begin
  assert (select fallback_model from ai_providers where provider = 'gemini') = 'gemini-2.0-flash', 'rejected calls changed nothing';
  assert not exists (select 1 from ai_providers where provider = 'anthropic'), 'no row created for an unsaved provider';
end $$;

\echo '--- fallback_model in the read RPCs; blank or null clears it; no key beyond the runtime api_key'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare s jsonb;
begin
  s := get_ai_settings();
  assert (select e->>'fallback_model' from jsonb_array_elements(s->'providers') e where e->>'provider' = 'gemini')
         = 'gemini-2.0-flash', 'settings expose fallback_model';
  assert (select e->'fallback_model' from jsonb_array_elements(s->'providers') e where e->>'provider' = 'openai')
         = 'null'::jsonb, 'unset fallback_model is null';
  assert (select e->'last_test_busy' from jsonb_array_elements(s->'providers') e where e->>'provider' = 'gemini')
         = 'true'::jsonb, 'settings expose last_test_busy';
  assert (select e->'last_test_busy' from jsonb_array_elements(s->'providers') e where e->>'provider' = 'openai')
         = 'false'::jsonb, 'openai last_test_busy false';
  assert position('test-key' in s::text) = 0, 'settings output has no key';
  assert not exists (select 1 from jsonb_array_elements(s->'providers') e where e ? 'secret_id' or e ? 'api_key'),
    'no secret fields';
end $$;
reset role;
set role service_role;
do $$
declare r jsonb;
begin
  r := get_ai_provider_runtime('gemini');
  assert r->>'fallback_model' = 'gemini-2.0-flash', 'provider runtime exposes fallback_model';
  assert r->>'api_key' = 'test-key-1234', 'provider runtime still has its api_key';
  assert not (r ? 'secret_id'), 'no secret_id in provider runtime';
  r := get_ai_provider_runtime('custom');
  assert r->'fallback_model' = 'null'::jsonb, 'unset fallback_model is null in provider runtime';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_settings('gemini', true);
end $$;
reset role;
set role service_role;
do $$
declare r jsonb;
begin
  r := get_ai_runtime();
  assert r->>'fallback_model' = 'gemini-2.0-flash', 'runtime exposes fallback_model';
  assert r->>'api_key' = 'test-key-1234', 'runtime still has its api_key';
  assert not (r ? 'secret_id'), 'no secret_id in runtime';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform set_ai_settings('gemini', false);
  perform set_ai_fallback_model('gemini', '   ');
  assert (select e->'fallback_model' from jsonb_array_elements(get_ai_settings()->'providers') e
          where e->>'provider' = 'gemini') = 'null'::jsonb, 'blank clears';
  perform set_ai_fallback_model('gemini', 'gemini-2.0-flash');
  perform set_ai_fallback_model('gemini', null);
  assert (select e->'fallback_model' from jsonb_array_elements(get_ai_settings()->'providers') e
          where e->>'provider' = 'gemini') = 'null'::jsonb, 'null clears';
end $$;
reset role;

\echo '--- ai_error_log: table closed to anon and authenticated; log_ai_error not executable by them'
create function pg_temp.check_ai_error_closed(u text, r text) returns void language plpgsql as $$
declare q text;
begin
  perform set_config('request.jwt.claim.sub', u, true);
  execute format('set local role %I', r);
  foreach q in array array[
    'select 1 from public.ai_error_log',
    'insert into public.ai_error_log (stage) values (''runtime'')',
    'update public.ai_error_log set kind = ''x''',
    'delete from public.ai_error_log',
    'select public.log_ai_error(''runtime'', ''gemini'', ''m'', ''k'', 500, ''d'')'
  ] loop
    begin execute q; raise exception 'FAIL % ai_error_log access: %', r, q;
    exception when insufficient_privilege then null; end;
  end loop;
  reset role;
end $$;
select pg_temp.check_ai_error_closed('', 'anon');
select pg_temp.check_ai_error_closed('00000000-0000-0000-0000-0000000000a1', 'authenticated');
select pg_temp.check_ai_error_closed('00000000-0000-0000-0000-0000000000b1', 'authenticated');

\echo '--- log_ai_error: service role writes, rejects a bad stage, truncates long text'
set role service_role;
do $$
declare r record;
begin
  perform log_ai_error('provider', repeat('p', 150), repeat('m', 150), repeat('k', 60), 429, repeat('d', 500));
  perform log_ai_error('empty', null, null, null, null, null);
  begin perform log_ai_error('bogus', 'gemini', 'm', 'k', 500, 'd');
    raise exception 'FAIL invalid stage'; exception when sqlstate '22023' then
      assert sqlerrm = 'invalid stage', 'invalid stage message, got ' || sqlerrm; end;
  begin perform log_ai_error(null, 'gemini', 'm', 'k', 500, 'd');
    raise exception 'FAIL null stage'; exception when sqlstate '22023' then null; end;
end $$;
reset role;
do $$ begin
  assert (select count(*) from ai_error_log) = 2, 'two rows logged, bad stages stored nothing';
  assert (select char_length(provider) from ai_error_log where stage = 'provider') = 100, 'provider cut to 100';
  assert (select char_length(model) from ai_error_log where stage = 'provider') = 100, 'model cut to 100';
  assert (select char_length(kind) from ai_error_log where stage = 'provider') = 30, 'kind cut to 30';
  assert (select char_length(detail) from ai_error_log where stage = 'provider') = 200, 'detail cut to 200';
  assert (select status from ai_error_log where stage = 'provider') = 429, 'status stored';
  assert (select provider is null and model is null and kind is null and status is null and detail is null
          from ai_error_log where stage = 'empty'), 'nulls stored as null';
end $$;
delete from ai_error_log;

\echo '--- log_ai_error: keeps only the newest 200 rows (205 separate calls, row-1 .. row-205)'
set role service_role;
select format('select public.log_ai_error(''runtime'', ''gemini'', ''fake-model'', ''fake'', 500, ''row-%s'')', i)
from generate_series(1, 205) i \gexec
reset role;
do $$ begin
  assert (select count(*) from ai_error_log) = 200, 'capped at 200, got ' || (select count(*) from ai_error_log);
  assert not exists (select 1 from ai_error_log where detail in ('row-1', 'row-2', 'row-3', 'row-4', 'row-5')), 'oldest 5 gone';
  assert exists (select 1 from ai_error_log where detail = 'row-6'), 'row-6 kept';
  assert exists (select 1 from ai_error_log where detail = 'row-205'), 'newest kept';
end $$;

\echo '--- get_ai_errors / clear_ai_errors: super admin only; newest first; limit clamp'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$ begin
  begin perform get_ai_errors();
    raise exception 'FAIL BA get_ai_errors'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
  begin perform clear_ai_errors();
    raise exception 'FAIL BA clear_ai_errors'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
end $$;
reset role;
select pg_temp.as_user('', 'anon');
do $$ begin
  begin perform get_ai_errors();
    raise exception 'FAIL anon get_ai_errors'; exception when sqlstate '42501' then null; end;
  begin perform clear_ai_errors();
    raise exception 'FAIL anon clear_ai_errors'; exception when sqlstate '42501' then null; end;
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare r jsonb;
begin
  r := get_ai_errors(3);
  assert jsonb_array_length(r) = 3, 'limit 3';
  assert r->0->>'detail' = 'row-205' and r->1->>'detail' = 'row-204' and r->2->>'detail' = 'row-203',
    'newest first, got ' || (r->0->>'detail') || ',' || (r->1->>'detail') || ',' || (r->2->>'detail');
  assert (select array_agg(k order by k) from jsonb_object_keys(r->0) k)
         = array['created_at', 'detail', 'id', 'kind', 'model', 'provider', 'stage', 'status'], 'row keys';
  assert jsonb_array_length(get_ai_errors()) = 20, 'default limit 20';
  assert jsonb_array_length(get_ai_errors(null)) = 20, 'null limit = 20';
  assert jsonb_array_length(get_ai_errors(0)) = 1, 'limit 0 clamps to 1';
  assert jsonb_array_length(get_ai_errors(-5)) = 1, 'negative limit clamps to 1';
  assert jsonb_array_length(get_ai_errors(1000)) = 100, 'limit 1000 clamps to 100';
  perform clear_ai_errors();
  assert get_ai_errors() = '[]'::jsonb, 'empty log = []';
end $$;
reset role;
do $$ begin
  assert (select count(*) from ai_error_log) = 0, 'clear_ai_errors deleted every row';
end $$;

\echo '--- ai_models: table closed to anon and authenticated; sync_ai_models not executable by them'
create function pg_temp.check_ai_models_closed(u text, r text) returns void language plpgsql as $$
declare q text;
begin
  perform set_config('request.jwt.claim.sub', u, true);
  execute format('set local role %I', r);
  foreach q in array array[
    'select 1 from public.ai_models',
    'insert into public.ai_models (provider, model_id, source) values (''gemini'', ''test-model-x'', ''manual'')',
    'update public.ai_models set label = ''x''',
    'delete from public.ai_models',
    'select public.sync_ai_models(''gemini'', array[''test-model-a''])'
  ] loop
    begin execute q; raise exception 'FAIL % ai_models access: %', r, q;
    exception when insufficient_privilege then null; end;
  end loop;
  reset role;
end $$;
select pg_temp.check_ai_models_closed('', 'anon');
select pg_temp.check_ai_models_closed('00000000-0000-0000-0000-0000000000a1', 'authenticated');
select pg_temp.check_ai_models_closed('00000000-0000-0000-0000-0000000000b1', 'authenticated');

\echo '--- list/add/remove_ai_model: 42501 for business admin and anon'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$ begin
  begin perform list_ai_models();
    raise exception 'FAIL BA list_ai_models'; exception when sqlstate '42501' then
      assert sqlerrm = 'forbidden', 'forbidden message, got ' || sqlerrm; end;
  begin perform add_ai_model('gemini', 'test-model-a');
    raise exception 'FAIL BA add_ai_model'; exception when sqlstate '42501' then null; end;
  begin perform remove_ai_model('gemini', 'test-model-a');
    raise exception 'FAIL BA remove_ai_model'; exception when sqlstate '42501' then null; end;
end $$;
reset role;
select pg_temp.as_user('', 'anon');
do $$ begin
  begin perform list_ai_models();
    raise exception 'FAIL anon list_ai_models'; exception when sqlstate '42501' then null; end;
  begin perform add_ai_model('gemini', 'test-model-a');
    raise exception 'FAIL anon add_ai_model'; exception when sqlstate '42501' then null; end;
  begin perform remove_ai_model('gemini', 'test-model-a');
    raise exception 'FAIL anon remove_ai_model'; exception when sqlstate '42501' then null; end;
end $$;
reset role;

\echo '--- add_ai_model / remove_ai_model / list_ai_models as super admin'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare r jsonb;
begin
  assert list_ai_models() = '[]'::jsonb, 'empty table lists []';
  begin perform list_ai_models('bogus');
    raise exception 'FAIL bogus list provider'; exception when sqlstate '22023' then null; end;
  begin perform add_ai_model('bogus', 'test-model-a');
    raise exception 'FAIL bogus add provider'; exception when sqlstate '22023' then null; end;
  begin perform add_ai_model('gemini', 'bad id!');
    raise exception 'FAIL bad id'; exception when sqlstate '22023' then
      assert sqlerrm = 'invalid model id', 'invalid model id message, got ' || sqlerrm; end;
  begin perform add_ai_model('gemini', repeat('m', 101));
    raise exception 'FAIL 101 characters'; exception when sqlstate '22023' then null; end;
  begin perform add_ai_model('gemini', '   ');
    raise exception 'FAIL blank id'; exception when sqlstate '22023' then null; end;
  begin perform add_ai_model('gemini', null);
    raise exception 'FAIL null id'; exception when sqlstate '22023' then null; end;
  assert list_ai_models() = '[]'::jsonb, 'rejected adds stored nothing';

  perform add_ai_model('gemini', '  test-model-a  ', 'Test A');
  perform add_ai_model('gemini', 'test-model-a', 'Other label');
  perform add_ai_model('gemini', repeat('m', 100));
  r := list_ai_models('gemini');
  assert jsonb_array_length(r) = 2, 'idempotent add, two rows, got ' || jsonb_array_length(r);
  assert r @> '[{"provider":"gemini","model_id":"test-model-a","label":"Test A","is_available":true,"source":"manual"}]'::jsonb,
    'manual row stored, trimmed, label kept';
  assert jsonb_array_length(list_ai_models('openai')) = 0, 'filter by provider';
  assert jsonb_array_length(list_ai_models()) = 2, 'unfiltered list';
  assert (select array_agg(k order by k) from jsonb_object_keys(r->0) k)
         = array['is_available', 'label', 'model_id', 'provider', 'source'], 'row keys';
end $$;
reset role;
do $$ begin
  assert (select count(*) from ai_models) = 2, 'two manual rows in the table';
end $$;

\echo '--- remove_ai_model: manual row deleted; provider row and model in use refused'
set role service_role;
select sync_ai_models('gemini', array['test-model-p']);
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$
declare v_model text;
begin
  begin perform remove_ai_model('bogus', 'test-model-a');
    raise exception 'FAIL bogus remove provider'; exception when sqlstate '22023' then null; end;
  begin perform remove_ai_model('gemini', 'test-model-p');
    raise exception 'FAIL provider row removed'; exception when sqlstate '22023' then
      assert sqlerrm = 'synced models cannot be removed', 'synced message, got ' || sqlerrm; end;
  perform remove_ai_model('gemini', 'test-model-a');
  perform remove_ai_model('gemini', 'no-such-model');
  assert (select count(*) from jsonb_array_elements(list_ai_models('gemini')) e
          where e->>'model_id' = 'test-model-a') = 0, 'manual row removed';

  -- saved model in use
  select e->>'model' into v_model from jsonb_array_elements(get_ai_settings()->'providers') e
    where e->>'provider' = 'gemini';
  perform add_ai_model('gemini', v_model);
  begin perform remove_ai_model('gemini', v_model);
    raise exception 'FAIL saved model removed'; exception when sqlstate '22023' then
      assert sqlerrm = 'model in use', 'in use message, got ' || sqlerrm; end;

  -- fallback in use
  perform add_ai_model('gemini', 'test-model-fb');
  perform set_ai_fallback_model('gemini', 'test-model-fb');
  begin perform remove_ai_model('gemini', 'test-model-fb');
    raise exception 'FAIL fallback removed'; exception when sqlstate '22023' then
      assert sqlerrm = 'model in use', 'fallback in use message, got ' || sqlerrm; end;
  perform set_ai_fallback_model('gemini', null);
  perform remove_ai_model('gemini', 'test-model-fb');
  assert (select count(*) from jsonb_array_elements(list_ai_models('gemini')) e
          where e->>'model_id' = 'test-model-fb') = 0, 'unused fallback model removed';
  perform remove_ai_model('gemini', repeat('m', 100));
end $$;
reset role;
do $$ begin
  assert exists (select 1 from ai_models where provider = 'gemini' and model_id = 'test-model-p' and source = 'provider'),
    'provider row survived';
  assert (select count(*) from ai_models where provider = 'gemini') = 2, 'provider row and in-use model remain';
end $$;
delete from ai_models;

\echo '--- sync_ai_models: upsert, mark missing unavailable, manual rows kept, manual to provider, skip invalid, cap, count'
set role service_role;
do $$
declare n int;
begin
  n := sync_ai_models('gemini', array['test-model-a', ' test-model-b ', 'test-model-a', 'bad id!', '', repeat('m', 101)]);
  assert n = 2, 'count of stored ids, got ' || n;
  assert sync_ai_models('openai', null) = 0, 'null list stores nothing';
  begin perform sync_ai_models('bogus', array['x']);
    raise exception 'FAIL bogus provider'; exception when sqlstate '22023' then null; end;
  begin perform sync_ai_models(null, array['x']);
    raise exception 'FAIL null provider'; exception when sqlstate '22023' then null; end;
  begin perform sync_ai_models('gemini', (select array_agg('test-model-' || i) from generate_series(1, 501) i));
    raise exception 'FAIL 501 ids'; exception when sqlstate '22023' then
      assert sqlerrm = 'too many models', 'too many message, got ' || sqlerrm; end;
  assert sync_ai_models('openai', (select array_agg('test-model-' || i) from generate_series(1, 500) i)) = 500,
    '500 ids accepted';
end $$;
reset role;
do $$ begin
  assert (select count(*) from ai_models where provider = 'gemini') = 2, 'two gemini rows, invalid ids skipped';
  assert (select count(*) from ai_models where provider = 'gemini' and source = 'provider' and is_available) = 2,
    'both stored as available provider rows';
  assert exists (select 1 from ai_models where provider = 'gemini' and model_id = 'test-model-b'), 'ids trimmed';
  assert (select count(*) from ai_models where provider = 'openai') = 500, 'rejected call stored nothing extra';
end $$;
delete from ai_models where provider = 'openai';

-- missing provider rows go unavailable, manual rows untouched, manual becomes provider when listed
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  perform add_ai_model('gemini', 'test-model-m1');
  perform add_ai_model('gemini', 'test-model-m2');
end $$;
reset role;
set role service_role;
do $$ begin
  assert sync_ai_models('gemini', array['test-model-b', 'test-model-m2', 'test-model-c']) = 3, 'second sync count';
end $$;
reset role;
do $$ begin
  assert (select is_available from ai_models where provider = 'gemini' and model_id = 'test-model-a') = false,
    'missing provider row marked unavailable';
  assert (select is_available and source = 'provider' from ai_models where provider = 'gemini' and model_id = 'test-model-b'),
    'listed provider row stays available';
  assert (select is_available and source = 'provider' from ai_models where provider = 'gemini' and model_id = 'test-model-c'),
    'new provider row stored';
  assert (select is_available and source = 'manual' from ai_models where provider = 'gemini' and model_id = 'test-model-m1'),
    'unlisted manual row untouched';
  assert (select source = 'provider' and is_available from ai_models where provider = 'gemini' and model_id = 'test-model-m2'),
    'listed manual row became provider';
end $$;
set role service_role;
do $$ begin
  assert sync_ai_models('gemini', array[]::text[]) = 0, 'empty list stores nothing';
end $$;
reset role;
do $$ begin
  assert not exists (select 1 from ai_models where provider = 'gemini' and source = 'provider' and is_available),
    'empty list marks every provider row unavailable';
  assert (select is_available and source = 'manual' from ai_models where provider = 'gemini' and model_id = 'test-model-m1'),
    'manual row still untouched';
  assert (select count(*) from ai_models where provider <> 'gemini') = 0, 'other providers untouched';
end $$;
delete from ai_models;

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
