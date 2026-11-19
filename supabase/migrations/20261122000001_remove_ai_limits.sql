-- =====================================================================================
-- Remove the app-side AI generation limits: drops log_ai_generation and the
-- ai_generation_log table (existing log rows are dropped with it), removes daily_limit
-- from ai_settings and from set_ai_settings / get_ai_settings / get_ai_runtime /
-- get_ai_provider_runtime. Cost control moves to the AI provider's console.
-- See docs/plans/07-remove-ai-limits/00-README.md (decision R1).
-- Runs after 20261121000001_ai_review.sql.
-- =====================================================================================

-- (1) + (2) Rate-limit function and its log table.
drop function if exists public.log_ai_generation(uuid, text);
drop table if exists public.ai_generation_log;

-- (3) set_ai_settings without the limit argument.
drop function if exists public.set_ai_settings(text, boolean, int);

create or replace function public.set_ai_settings(
  p_active_provider text, p_is_enabled boolean
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_active_provider is not null and p_active_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;
  if coalesce(p_is_enabled, false) then
    perform 1 from public.ai_providers p
      where p.provider = p_active_provider and p.secret_id is not null
      for share;
    if not found then
      raise exception 'provider has no key' using errcode = '22023';
    end if;
  end if;

  update public.ai_settings
    set active_provider = p_active_provider,
        is_enabled = coalesce(p_is_enabled, false),
        updated_at = now()
    where id;
end $$;

revoke all on function public.set_ai_settings(text, boolean) from public, anon, authenticated;
grant execute on function public.set_ai_settings(text, boolean) to authenticated;

-- (4) The column. The getters reference it, so drop them first and recreate them in (5).
drop function if exists public.get_ai_settings();
drop function if exists public.get_ai_runtime();
drop function if exists public.get_ai_provider_runtime(text);

alter table public.ai_settings drop column if exists daily_limit;

-- (5) Recreate without daily_limit.
-- Never returns a key or a secret id.
create function public.get_ai_settings() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_out jsonb;
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'active_provider', s.active_provider,
    'is_enabled', s.is_enabled,
    'providers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'provider', p.provider,
        'model', p.model,
        'base_url', p.base_url,
        'has_key', p.secret_id is not null,
        'key_hint', p.key_hint,
        'updated_at', p.updated_at
      ) order by p.provider)
      from public.ai_providers p
    ), '[]'::jsonb)
  ) into v_out
  from public.ai_settings s;
  return v_out;
end $$;

revoke all on function public.get_ai_settings() from public, anon, authenticated;
grant execute on function public.get_ai_settings() to authenticated;

-- {provider, model, base_url, api_key} when enabled and the active provider has a key.
create function public.get_ai_runtime() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'provider', p.provider,
    'model', p.model,
    'base_url', p.base_url,
    'api_key', d.decrypted_secret
  )
  from public.ai_settings s
  join public.ai_providers p on p.provider = s.active_provider and p.secret_id is not null
  join vault.decrypted_secrets d on d.id = p.secret_id
  where s.is_enabled
$$;

-- Same shape for a named provider if it has a key (enabled or not); used by test-ai.
create function public.get_ai_provider_runtime(p_provider text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'provider', p.provider,
    'model', p.model,
    'base_url', p.base_url,
    'api_key', d.decrypted_secret
  )
  from public.ai_providers p
  join vault.decrypted_secrets d on d.id = p.secret_id
  where p.provider = p_provider and p.secret_id is not null
$$;

revoke all on function
  public.get_ai_runtime(),
  public.get_ai_provider_runtime(text)
from public, anon, authenticated;
grant execute on function
  public.get_ai_runtime(),
  public.get_ai_provider_runtime(text)
to service_role;
