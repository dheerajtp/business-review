-- AI error log: the last 200 failed AI review generations, for the Super Admin to read.
-- Stores no prompt, no review text, no customer data, no key and no branch or keyword ids.
-- Access only through the RPCs below.

-- ---------- 1. Table ----------
create table public.ai_error_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  stage text not null check (stage in ('context', 'runtime', 'not_configured', 'provider', 'empty')),
  provider text null,
  model text null,
  kind text null check (char_length(kind) <= 30),
  status int null,
  detail text null check (char_length(detail) <= 200)
);

create index ai_error_log_created_at_idx on public.ai_error_log (created_at desc);

alter table public.ai_error_log enable row level security;
revoke all on public.ai_error_log from anon, authenticated;

-- ---------- 2. Write RPC. Service role only (Edge Function) ----------
create function public.log_ai_error(
  p_stage text, p_provider text, p_model text, p_kind text, p_status int, p_detail text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_stage is null or p_stage not in ('context', 'runtime', 'not_configured', 'provider', 'empty') then
    raise exception 'invalid stage' using errcode = '22023';
  end if;

  insert into public.ai_error_log (stage, provider, model, kind, status, detail)
  values (p_stage, left(p_provider, 100), left(p_model, 100), left(p_kind, 30), p_status, left(p_detail, 200));

  -- keep only the newest 200 rows
  delete from public.ai_error_log
  where id in (select id from public.ai_error_log order by created_at desc, id desc offset 200);
end $$;

revoke all on function public.log_ai_error(text, text, text, text, int, text) from public, anon, authenticated;
grant execute on function public.log_ai_error(text, text, text, text, int, text) to service_role;

-- ---------- 3. Read and clear RPCs. Super Admin only ----------
create function public.get_ai_errors(p_limit int default 20) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', e.id,
      'created_at', e.created_at,
      'stage', e.stage,
      'provider', e.provider,
      'model', e.model,
      'kind', e.kind,
      'status', e.status,
      'detail', e.detail
    ) order by e.created_at desc, e.id desc), '[]'::jsonb)
    from (
      select * from public.ai_error_log
      order by created_at desc, id desc
      limit least(greatest(coalesce(p_limit, 20), 1), 100)
    ) e
  );
end $$;

create function public.clear_ai_errors() returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  delete from public.ai_error_log;
end $$;

revoke all on function public.get_ai_errors(int), public.clear_ai_errors() from public, anon;
grant execute on function public.get_ai_errors(int), public.clear_ai_errors() to authenticated;
