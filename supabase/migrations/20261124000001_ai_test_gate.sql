-- =====================================================================================
-- AI test gate: a provider must pass a live test (test-ai Edge Function) before AI can be
-- enabled. Adds last_test_ok / last_tested_at, record_ai_test (service role), reset-on-change
-- in set_ai_provider / clear_ai_provider_key, the enable gate in set_ai_settings, and the
-- flag in get_feedback_form / get_ai_settings.
-- See docs/plans/10-ai-test-gate/00-README.md (decisions T1-T6).
-- Runs after 20261123000001_ai_error_log.sql.
-- =====================================================================================

-- ---------- 1. Columns (T1). Existing rows start as not tested ----------
alter table public.ai_providers
  add column last_test_ok boolean not null default false,
  add column last_tested_at timestamptz null;

-- ---------- 2. record_ai_test (T2). Service role only ----------
create or replace function public.record_ai_test(p_provider text, p_ok boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_provider is null or p_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;
  update public.ai_providers
    set last_test_ok = coalesce(p_ok, false), last_tested_at = now()
    where provider = p_provider;
end $$;

revoke all on function public.record_ai_test(text, boolean) from public, anon, authenticated;
grant execute on function public.record_ai_test(text, boolean) to service_role;

-- ---------- 3. Reset on change (T3) ----------
-- Same signature and rules as before; the test result resets when the model, base URL or key
-- changes. A null/empty key with unchanged model and base URL leaves the result alone.
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
    set secret_id = null, key_hint = null, last_test_ok = false, last_tested_at = null,
        updated_at = now()
    where provider = p_provider;
  update public.ai_settings
    set is_enabled = false, updated_at = now()
    where active_provider = p_provider and is_enabled;
end $$;

-- ---------- 4. Enable gate (T4) ----------
-- Enabling (including switching the active provider while enabled) needs a key first, then a
-- passed test. Disabling is always allowed.
create or replace function public.set_ai_settings(
  p_active_provider text, p_is_enabled boolean
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_tested boolean;
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_active_provider is not null and p_active_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;
  if coalesce(p_is_enabled, false) then
    select p.last_test_ok into v_tested from public.ai_providers p
      where p.provider = p_active_provider and p.secret_id is not null
      for share;
    if not found then
      raise exception 'provider has no key' using errcode = '22023';
    end if;
    if not coalesce(v_tested, false) then
      raise exception 'provider not tested' using errcode = '22023';
    end if;
  end if;

  update public.ai_settings
    set active_provider = p_active_provider,
        is_enabled = coalesce(p_is_enabled, false),
        updated_at = now()
    where id;
end $$;

-- ---------- 5. Form RPC (T5). Same body, signature and grants; ai_enabled also needs a passed test ----------
drop function public.get_feedback_form(text);

-- Not found (null) when the branch, company, subcategory or category is inactive.
-- keywords = the branch's effective active keywords in position order (max 10); none = [].
-- ai_enabled = AI is switched on and the active provider has a saved key and a passed test.
create function public.get_feedback_form(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'branch_name', b.name,
    'company_name', c.name,
    'google_place_id', b.google_place_id,
    'category_name', k.name,
    'subcategory_name', s.name,
    'keywords', coalesce((
      select jsonb_agg(jsonb_build_object('id', w.id, 'label', w.label) order by e.pos)
      from public.effective_keyword_ids(b.id) e
      join public.keywords w on w.id = e.keyword_id and w.is_active
    ), '[]'::jsonb),
    'ai_enabled', coalesce((
      select a.is_enabled and exists (
        select 1 from public.ai_providers p
        where p.provider = a.active_provider and p.secret_id is not null and p.last_test_ok
      )
      from public.ai_settings a
    ), false)
  )
  from public.branches b
  join public.companies c on c.id = b.company_id and c.is_active
  join public.subcategories s on s.id = c.subcategory_id and s.is_active
  join public.categories k on k.id = s.category_id and k.is_active
  where b.slug = p_slug and b.is_active
$$;

revoke all on function public.get_feedback_form(text) from public;
grant execute on function public.get_feedback_form(text) to anon, authenticated;

-- ---------- 6. Settings read (T6). Never returns a key or a secret id ----------
drop function public.get_ai_settings();

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
        'updated_at', p.updated_at,
        'last_test_ok', p.last_test_ok,
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
