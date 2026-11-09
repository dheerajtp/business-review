-- One round trip of pre-aggregated numbers for the dashboard charts.
-- SECURITY INVOKER (the default): row level security still decides what the caller can see,
-- so a Business Admin calling this would only ever get their own company's numbers.
create function public.dashboard_stats(p_days int default 30, p_company uuid default null, p_tz text default 'UTC')
returns jsonb
language plpgsql stable set search_path = public as $$
declare
  d int := least(greatest(coalesce(p_days, 30), 1), 365);
  tz text := coalesce(nullif(p_tz, ''), 'UTC');
  today date := (now() at time zone tz)::date;
  start_cur timestamptz := (today - (d - 1))::timestamp at time zone tz;
  start_prev timestamptz := (today - (2 * d - 1))::timestamp at time zone tz;
  res jsonb;
begin
  with f as (
    select * from public.feedback_submissions
    where created_at >= start_prev and (p_company is null or company_id = p_company)
  ),
  cur as (select * from f where created_at >= start_cur),
  prev as (select * from f where created_at < start_cur)
  select jsonb_build_object(
    'days', d,
    'summary', jsonb_build_object(
      'cur', (select jsonb_build_object('total', count(*), 'avg', round(avg(rating)::numeric, 2),
                'low', count(*) filter (where rating < 4), 'happy', count(*) filter (where rating >= 4),
                'google', count(*) filter (where rating >= 4 and clicked_google)) from cur),
      'prev', (select jsonb_build_object('total', count(*), 'avg', round(avg(rating)::numeric, 2),
                'low', count(*) filter (where rating < 4), 'happy', count(*) filter (where rating >= 4),
                'google', count(*) filter (where rating >= 4 and clicked_google)) from prev)
    ),
    'daily', (
      select coalesce(jsonb_agg(jsonb_build_object('day', g.day, 'high', coalesce(c.high, 0), 'low', coalesce(c.low, 0)) order by g.day), '[]'::jsonb)
      from (select x::date as day from generate_series((today - (d - 1))::timestamp, today::timestamp, interval '1 day') x) g
      left join (
        select (created_at at time zone tz)::date as day,
               count(*) filter (where rating >= 4) as high, count(*) filter (where rating < 4) as low
        from cur group by 1
      ) c on c.day = g.day
    ),
    'mix', (
      select jsonb_agg(jsonb_build_object('rating', r, 'n', coalesce(c.n, 0)) order by r)
      from generate_series(1, 5) r
      left join (select rating, count(*) as n from cur group by rating) c on c.rating = r
    ),
    'companies', (
      select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'total', x.total, 'avg', x.avg, 'low', x.low)
               order by (x.total = 0), x.avg, x.name), '[]'::jsonb)
      from (
        select co.id, co.name, count(c.id) as total, round(avg(c.rating)::numeric, 2) as avg,
               count(c.id) filter (where c.rating < 4) as low
        from public.companies co left join cur c on c.company_id = co.id
        where p_company is null or co.id = p_company
        group by co.id, co.name
      ) x
    ),
    'branches', (
      select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'company', x.company, 'total', x.total, 'avg', x.avg, 'low', x.low)
               order by (x.total = 0), x.avg, x.name), '[]'::jsonb)
      from (
        select b.id, b.name, co.name as company, count(c.id) as total, round(avg(c.rating)::numeric, 2) as avg,
               count(c.id) filter (where c.rating < 4) as low
        from public.branches b
        join public.companies co on co.id = b.company_id
        left join cur c on c.branch_id = b.id
        where p_company is null or b.company_id = p_company
        group by b.id, b.name, co.name
      ) x
    )
  ) into res;
  return res;
end $$;

revoke all on function public.dashboard_stats(int, uuid, text) from public;
grant execute on function public.dashboard_stats(int, uuid, text) to authenticated;
