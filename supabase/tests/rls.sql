-- Run after stubs + migration. Any failed assertion aborts with an error.
\set ON_ERROR_STOP on
create temp table _ids (k text primary key, v uuid);
grant all on _ids to anon, authenticated;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'super@x'),
  ('00000000-0000-0000-0000-0000000000b1', 'cafe@x'),
  ('00000000-0000-0000-0000-0000000000b2', 'boutique@x');

insert into categories (id, name) values
  ('10000000-0000-0000-0000-000000000001', 'Cafe'),
  ('10000000-0000-0000-0000-000000000002', 'Boutique');
insert into companies (id, name, category_id) values
  ('20000000-0000-0000-0000-000000000001', 'Brew Co', '10000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002', 'Silk House', '10000000-0000-0000-0000-000000000002');
insert into branches (id, company_id, name, slug, google_place_id) values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Brew MG Road', 'brew1', 'PLACE_BREW'),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'Silk Mall', 'silk1', 'PLACE_SILK');
insert into profiles (user_id, role, company_id) values
  ('00000000-0000-0000-0000-0000000000a1', 'super_admin', null),
  ('00000000-0000-0000-0000-0000000000b1', 'business_admin', '20000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-0000000000b2', 'business_admin', '20000000-0000-0000-0000-000000000002');
insert into questions (id, category_id, company_id, text, type, options, is_required, sort_order) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', null, 'Coffee quality?', 'scale', null, true, 1),
  ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', null, 'What did you order?', 'multi', '["Coffee","Food","Dessert"]', false, 2),
  ('40000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Brew-only: try the new menu?', 'single', '["Yes","No"]', false, 3),
  ('40000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', null, 'Fabric quality?', 'scale', null, false, 1);

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
end $$;

\echo '--- form RPC: category + company questions, ordered, no leakage'
do $$
declare f jsonb;
begin
  f := get_feedback_form('brew1');
  assert f->>'branch_name' = 'Brew MG Road', 'branch name';
  assert f->>'google_place_id' = 'PLACE_BREW', 'place id';
  assert jsonb_array_length(f->'questions') = 3, 'brew should have 3 questions, got ' || jsonb_array_length(f->'questions');
  assert f->'questions'->2->>'text' like 'Brew-only%', 'company question last';
  f := get_feedback_form('silk1');
  assert jsonb_array_length(f->'questions') = 1, 'silk has 1 question';
  assert get_feedback_form('nope') is null, 'unknown slug null';
end $$;

\echo '--- submit: valid, invalid'
do $$
declare id uuid; ok boolean;
begin
  id := submit_feedback('brew1', 2,
    '{"40000000-0000-0000-0000-000000000001": 3, "40000000-0000-0000-0000-000000000002": ["Coffee"]}',
    'slow service', '98765');
  assert id is not null;

  -- helper to assert an error
  begin perform submit_feedback('brew1', 0, '{"40000000-0000-0000-0000-000000000001": 3}', null, null);
    raise exception 'FAIL rating 0'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 6, '{"40000000-0000-0000-0000-000000000001": 3}', null, null);
    raise exception 'FAIL rating 6'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, '{}', null, null);
    raise exception 'FAIL missing required'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, '{"40000000-0000-0000-0000-000000000001": 9}', null, null);
    raise exception 'FAIL scale 9'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, '{"40000000-0000-0000-0000-000000000004": 3, "40000000-0000-0000-0000-000000000001": 3}', null, null);
    raise exception 'FAIL other category question'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, '{"40000000-0000-0000-0000-000000000001": 3, "40000000-0000-0000-0000-000000000003": "Maybe"}', null, null);
    raise exception 'FAIL bad option'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, '{"40000000-0000-0000-0000-000000000001": 3, "40000000-0000-0000-0000-000000000002": ["Pizza"]}', null, null);
    raise exception 'FAIL bad multi'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('brew1', 5, '{"40000000-0000-0000-0000-000000000001": 3}', repeat('x', 2001), null);
    raise exception 'FAIL long comment'; exception when sqlstate '22023' then null; end;
  begin perform submit_feedback('nope', 5, '{}', null, null);
    raise exception 'FAIL unknown slug'; exception when sqlstate 'P0002' then null; end;
  -- silk question is optional
  perform submit_feedback('silk1', 5, '{}', null, null);
  perform mark_google_click(id);
end $$;

reset role;
do $$ begin
  assert (select count(*) from feedback_submissions) = 2, 'exactly 2 stored (invalid ones rejected)';
  assert (select clicked_google from feedback_submissions where rating = 2), 'click recorded';
  assert (select company_id from feedback_submissions where rating = 5) = '20000000-0000-0000-0000-000000000002', 'company derived server-side';
  assert (select answers->0->>'text' from feedback_submissions where rating = 2) = 'Coffee quality?', 'snapshot';
end $$;

\echo '--- inactive branch/company/category are hidden and reject'
update branches set is_active = false where slug = 'silk1';
do $$ begin
  set local role anon;
  assert get_feedback_form('silk1') is null;
  begin perform submit_feedback('silk1', 5, '{}', null, null); raise exception 'FAIL inactive';
  exception when sqlstate 'P0002' then null; end;
end $$;
reset role;
update branches set is_active = true where slug = 'silk1';

\echo '--- business admin isolation'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b1', 'authenticated');
do $$ begin
  assert (select count(*) from feedback_submissions) = 1, 'BA1 sees only own feedback';
  assert (select count(*) from branches) = 1, 'BA1 sees only own branches';
  assert (select count(*) from companies) = 1;
  assert (select count(*) from question_requests) = 0;
  assert (select count(*) from questions) = 3, 'BA1 sees category + own questions only';
  assert (select count(*) from branch_stats) = 1, 'stats scoped';
  begin update branches set google_place_id = 'EVIL' where true; 
    assert (select count(*) from branches where google_place_id = 'EVIL') = 0, 'FAIL BA update branch';
  exception when insufficient_privilege then null; end;
  begin insert into questions (category_id, text, type) values ('10000000-0000-0000-0000-000000000001', 'x', 'text');
    raise exception 'FAIL BA insert question'; exception when insufficient_privilege or sqlstate '42501' then null; end;
  begin delete from feedback_submissions; raise exception 'FAIL BA delete feedback';
  exception when insufficient_privilege then null; end;
  begin update feedback_submissions set rating = 5; raise exception 'FAIL BA update feedback';
  exception when insufficient_privilege then null; end;
  -- request for own company ok; for another company / pre-approved denied
  insert into question_requests (company_id, requested_by, text)
    values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1', 'Ask about wifi');
  begin insert into question_requests (company_id, requested_by, text)
    values ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000b1', 'x');
    raise exception 'FAIL cross-company request'; exception when sqlstate '42501' then null; end;
  begin insert into question_requests (company_id, requested_by, text, status)
    values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1', 'x', 'approved');
    raise exception 'FAIL self-approve'; exception when sqlstate '42501' then null; end;
  begin update question_requests set status = 'approved'; 
    assert (select count(*) from question_requests where status = 'approved') = 0, 'FAIL BA self-approve via update';
  exception when insufficient_privilege then null; end;
  begin insert into profiles (user_id, role) values (gen_random_uuid(), 'super_admin');
    raise exception 'FAIL BA insert profile'; exception when insufficient_privilege then null; end;
end $$;
reset role;

\echo '--- business admin 2 cannot see BA1 request; super sees everything'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'authenticated');
do $$ begin
  assert (select count(*) from question_requests) = 0;
  assert (select count(*) from feedback_submissions) = 1;
  assert (select company_id from feedback_submissions) = '20000000-0000-0000-0000-000000000002';
end $$;
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'authenticated');
do $$ begin
  assert (select count(*) from feedback_submissions) = 2;
  assert (select count(*) from companies) = 2;
  assert (select count(*) from question_requests) = 1;
  update question_requests set status = 'approved', reviewed_by = auth.uid();
  -- company-scoped question must match category
  begin insert into questions (category_id, company_id, text, type)
    values ('10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'x', 'text');
    raise exception 'FAIL category mismatch'; exception when raise_exception then null; end;
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
  assert (select count(*) from feedback_submissions) = 0;
end $$;
reset role;
\echo 'ALL RLS TESTS PASSED'
