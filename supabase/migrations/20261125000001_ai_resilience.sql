-- =====================================================================================
-- AI resilience: optional per-provider fallback model, and a "busy" flag on the test result
-- (the provider answered but was overloaded). record_ai_test gets a third argument, the
-- reset rules also clear the flag, and the read RPCs expose the new fields.
-- See docs/plans/11-ai-resilience/00-README.md (decisions F1-F4).
-- Runs after 20261124000001_ai_test_gate.sql.
-- =====================================================================================

-- ---------- 1. Columns (F1) ----------
alter table public.ai_providers
  add column fallback_model text null
    check (fallback_model is null or char_length(fallback_model) between 1 and 100),
  add column last_test_busy boolean not null default false;

-- ---------- 2. set_ai_fallback_model (F2). Super admin only; does not reset the test ----------
create function public.set_ai_fallback_model(p_provider text, p_model text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_model text := nullif(btrim(p_model), '');
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_provider is null or p_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;
  if v_model is not null and char_length(v_model) not between 1 and 100 then
    raise exception 'invalid model' using errcode = '22023';
  end if;

  update public.ai_providers
    set fallback_model = v_model, updated_at = now()
    where provider = p_provider;
  if not found then
    raise exception 'save the provider first' using errcode = '22023';
  end if;
end $$;

revoke all on function public.set_ai_fallback_model(text, text) from public, anon;
grant execute on function public.set_ai_fallback_model(text, text) to authenticated;

-- ---------- 3. record_ai_test with a busy flag (F3). Service role only ----------
drop function public.record_ai_test(text, boolean);

create function public.record_ai_test(p_provider text, p_ok boolean, p_busy boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_provider is null or p_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;
  update public.ai_providers
    set last_test_ok = coalesce(p_ok, false),
        last_test_busy = coalesce(p_busy, false) and coalesce(p_ok, false),
        last_tested_at = now()
    where provider = p_provider;
end $$;

revoke all on function public.record_ai_test(text, boolean, boolean) from public, anon, authenticated;
grant execute on function public.record_ai_test(text, boolean, boolean) to service_role;

-- ---------- 4. Reset on change also clears the busy flag (F3) ----------
create or replace function public.set_ai_provider(
  p_provider text, p_model text, p_base_url text, p_api_key text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_model text := btrim(p_model);
  v_url text := nullif(btrim(p_base_url), '');
  v_key text := nullif(p_api_key, '');
  v_sid uuid;
  v_old public.ai_providers%rowtype;
  v_reset boolean;
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_provider is null or p_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;
  if v_model is null or char_length(v_model) not between 1 and 100 then
    raise exception 'invalid model' using errcode = '22023';
  end if;
  if (p_provider in ('gemini', 'anthropic') and v_url is not null)
     or (p_provider = 'custom' and v_url is null)
     or (v_url is not null and not public.ai_valid_base_url(v_url)) then
    raise exception 'invalid base url' using errcode = '22023';
  end if;
  v_url := rtrim(v_url, '/');
  if v_key is not null and (char_length(v_key) not between 8 and 400 or v_key ~ '\s') then
    raise exception 'invalid api key' using errcode = '22023';
  end if;

  select * into v_old from public.ai_providers p where p.provider = p_provider for update;
  v_reset := not found
    or v_old.model is distinct from v_model
    or v_old.base_url is distinct from v_url
    or v_key is not null;

  insert into public.ai_providers (provider, model, base_url, updated_at)
  values (p_provider, v_model, v_url, now())
  on conflict (provider) do update
    set model = excluded.model, base_url = excluded.base_url, updated_at = excluded.updated_at,
        last_test_ok = case when v_reset then false else public.ai_providers.last_test_ok end,
        last_test_busy = case when v_reset then false else public.ai_providers.last_test_busy end,
        last_tested_at = case when v_reset then null else public.ai_providers.last_tested_at end;

  -- A null or empty key keeps the saved one.
  if v_key is not null then
    select p.secret_id into v_sid from public.ai_providers p where p.provider = p_provider for update;
    if v_sid is null then
      v_sid := vault.create_secret(v_key, 'ai_key_' || p_provider, 'AI provider key');
    else
      perform vault.update_secret(v_sid, v_key);
    end if;
    update public.ai_providers
      set secret_id = v_sid, key_hint = right(v_key, 4), updated_at = now()
      where provider = p_provider;
  end if;
end $$;

create or replace function public.clear_ai_provider_key(p_provider text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_sid uuid;
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_provider is null or p_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;

  select p.secret_id into v_sid from public.ai_providers p where p.provider = p_provider for update;
  if v_sid is not null then
    delete from vault.secrets where id = v_sid;
  end if;
  update public.ai_providers
    set secret_id = null, key_hint = null, last_test_ok = false, last_test_busy = false,
        last_tested_at = null, updated_at = now()
    where provider = p_provider;
  update public.ai_settings
    set is_enabled = false, updated_at = now()
    where active_provider = p_provider and is_enabled;
end $$;

-- ---------- 5. Reads include the new fields (F4) ----------
drop function public.get_ai_settings();
drop function public.get_ai_runtime();
drop function public.get_ai_provider_runtime(text);

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
        'fallback_model', p.fallback_model,
        'base_url', p.base_url,
        'has_key', p.secret_id is not null,
        'key_hint', p.key_hint,
        'updated_at', p.updated_at,
        'last_test_ok', p.last_test_ok,
        'last_test_busy', p.last_test_busy,
        'last_tested_at', p.last_tested_at
      ) order by p.provider)
      from public.ai_providers p
    ), '[]'::jsonb)
  ) into v_out
  from public.ai_settings s;
  return v_out;
end $$;

revoke all on function public.get_ai_settings() from public, anon, authenticated;
grant execute on function public.get_ai_settings() to authenticated;

-- {provider, model, fallback_model, base_url, api_key} when enabled and the active provider has a key.
create function public.get_ai_runtime() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'provider', p.provider,
    'model', p.model,
    'fallback_model', p.fallback_model,
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
    'fallback_model', p.fallback_model,
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
