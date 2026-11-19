-- =====================================================================================
-- AI review generation: global provider settings, provider keys in Supabase Vault,
-- admin RPCs, service-role runtime RPCs, and the ai_enabled flag on the form RPC.
-- See docs/plans/06-ai-review-generation/00-README.md (decisions A1-A4, A6, A11).
-- Runs after 20261120000001_company_keywords.sql. Needs Supabase Vault (vault schema).
-- =====================================================================================

-- ---------- 1. Tables (A1). No direct access for any client role; RPCs only ----------
create table public.ai_settings (
  id boolean primary key default true check (id),
  active_provider text null check (active_provider in ('gemini', 'anthropic', 'openai', 'custom')),
  is_enabled boolean not null default false,
  daily_limit int not null default 2000 check (daily_limit between 1 and 100000),
  updated_at timestamptz default now()
);
insert into public.ai_settings (id) values (true);

create table public.ai_providers (
  provider text primary key check (provider in ('gemini', 'anthropic', 'openai', 'custom')),
  model text not null check (char_length(model) between 1 and 100),
  base_url text null,
  secret_id uuid null,
  key_hint text null,
  updated_at timestamptz not null default now()
);

create table public.ai_generation_log (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  client_hash text,
  created_at timestamptz not null default now()
);
create index ai_generation_log_client_idx on public.ai_generation_log (branch_id, client_hash, created_at);
create index ai_generation_log_created_at_idx on public.ai_generation_log (created_at);

alter table public.ai_settings enable row level security;
alter table public.ai_providers enable row level security;
alter table public.ai_generation_log enable row level security;
revoke all on public.ai_settings, public.ai_providers, public.ai_generation_log from anon, authenticated;

-- ---------- 2. Base URL guard (A6). Internal: only set_ai_provider calls it ----------
-- https only, <= 300 chars, no credentials, query or fragment; host is not localhost, an IP
-- literal, or a .local / .internal name.
create function public.ai_valid_base_url(p_url text) returns boolean
language sql immutable set search_path = public as $$
  select coalesce(
    char_length(p_url) <= 300
    and p_url !~ '\s'
    and p_url ~ '^https://([^/:@?#]+)(:[0-9]+)?(/[^?#]*)?$'
    and (
      select x.h <> 'localhost'
        and x.h !~ '^[0-9.]+$'
        and position(':' in x.h) = 0
        and position('[' in x.h) = 0
        and x.h !~ '\.(local|internal)$'
      from (select rtrim(lower(substring(p_url from '^https://([^/:@?#]+)')), '.') as h) x
    ),
    false)
$$;

revoke all on function public.ai_valid_base_url(text) from public, anon, authenticated;

-- ---------- 3. Admin RPCs (A2). Super Admin only ----------
create function public.set_ai_provider(
  p_provider text, p_model text, p_base_url text, p_api_key text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_model text := btrim(p_model);
  v_url text := nullif(btrim(p_base_url), '');
  v_key text := nullif(p_api_key, '');
  v_sid uuid;
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

  insert into public.ai_providers (provider, model, base_url, updated_at)
  values (p_provider, v_model, v_url, now())
  on conflict (provider) do update
    set model = excluded.model, base_url = excluded.base_url, updated_at = excluded.updated_at;

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

create function public.clear_ai_provider_key(p_provider text) returns void
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
    set secret_id = null, key_hint = null, updated_at = now()
    where provider = p_provider;
  update public.ai_settings
    set is_enabled = false, updated_at = now()
    where active_provider = p_provider and is_enabled;
end $$;

create function public.set_ai_settings(
  p_active_provider text, p_is_enabled boolean, p_daily_limit int
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_active_provider is not null and p_active_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;
  if p_daily_limit is null or p_daily_limit not between 1 and 100000 then
    raise exception 'invalid daily limit' using errcode = '22023';
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
        daily_limit = p_daily_limit,
        updated_at = now()
    where id;
end $$;

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
    'daily_limit', s.daily_limit,
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

revoke all on function
  public.set_ai_provider(text, text, text, text),
  public.clear_ai_provider_key(text),
  public.set_ai_settings(text, boolean, int),
  public.get_ai_settings()
from public;
grant execute on function
  public.set_ai_provider(text, text, text, text),
  public.clear_ai_provider_key(text),
  public.set_ai_settings(text, boolean, int),
  public.get_ai_settings()
to authenticated;

-- ---------- 4. Runtime RPCs for the Edge Functions (A3). Service role only ----------
-- {provider, model, base_url, api_key, daily_limit} when enabled and the active provider has a key.
create function public.get_ai_runtime() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'provider', p.provider,
    'model', p.model,
    'base_url', p.base_url,
    'api_key', d.decrypted_secret,
    'daily_limit', s.daily_limit
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
    'api_key', d.decrypted_secret,
    'daily_limit', s.daily_limit
  )
  from public.ai_providers p
  join vault.decrypted_secrets d on d.id = p.secret_id
  cross join public.ai_settings s
  where p.provider = p_provider and p.secret_id is not null
$$;

-- Null when the branch, company, subcategory or category is inactive or unknown. labels = the
-- requested keywords' labels in request order (duplicates merged at their first position); every
-- id must be an active keyword in the branch's effective set, at most 10 distinct.
create function public.get_review_context(p_slug text, p_keyword_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_branch_id uuid;
  v_ctx jsonb;
  v_ids uuid[];
  v_labels jsonb;
  v_found int;
begin
  select b.id, jsonb_build_object(
    'branch_id', b.id,
    'company_name', c.name,
    'branch_name', b.name,
    'category_name', k.name,
    'subcategory_name', s.name
  )
  into v_branch_id, v_ctx
  from public.branches b
  join public.companies c on c.id = b.company_id and c.is_active
  join public.subcategories s on s.id = c.subcategory_id and s.is_active
  join public.categories k on k.id = s.category_id and k.is_active
  where b.slug = p_slug and b.is_active;
  if not found then return null; end if;

  -- A null element stays in the list and is rejected below as an unknown keyword.
  select coalesce(array_agg(x.id order by x.pos), '{}') into v_ids
  from (
    select u.id, min(u.pos) as pos
    from unnest(coalesce(p_keyword_ids, '{}'::uuid[])) with ordinality as u(id, pos)
    group by u.id
  ) x;
  if cardinality(v_ids) > 10 then
    raise exception 'unknown keyword' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(w.label order by u.pos), '[]'::jsonb), count(*)
    into v_labels, v_found
  from unnest(v_ids) with ordinality as u(id, pos)
  join public.keywords w on w.id = u.id and w.is_active
  where exists (select 1 from public.effective_keyword_ids(v_branch_id) e where e.keyword_id = u.id);
  if v_found <> cardinality(v_ids) then
    raise exception 'unknown keyword' using errcode = '22023';
  end if;

  return v_ctx || jsonb_build_object('labels', v_labels);
end $$;

-- False when this branch + client already has 6 rows in the last 10 minutes, or all clients
-- together reached daily_limit in the last 24 hours; otherwise records one generation.
create function public.log_ai_generation(p_branch_id uuid, p_client_hash text) returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_limit int;
begin
  -- Lock the settings row so concurrent calls count one after the other.
  select s.daily_limit into v_limit from public.ai_settings s where s.id for update;

  delete from public.ai_generation_log where created_at < now() - interval '7 days';

  if (select count(*) from public.ai_generation_log l
      where l.branch_id = p_branch_id and l.client_hash is not distinct from p_client_hash
        and l.created_at > now() - interval '10 minutes') >= 6 then
    return false;
  end if;
  if (select count(*) from public.ai_generation_log l
      where l.created_at > now() - interval '24 hours') >= v_limit then
    return false;
  end if;

  insert into public.ai_generation_log (branch_id, client_hash) values (p_branch_id, p_client_hash);
  return true;
end $$;

revoke all on function
  public.get_ai_runtime(),
  public.get_ai_provider_runtime(text),
  public.get_review_context(text, uuid[]),
  public.log_ai_generation(uuid, text)
from public, anon, authenticated;
grant execute on function
  public.get_ai_runtime(),
  public.get_ai_provider_runtime(text),
  public.get_review_context(text, uuid[]),
  public.log_ai_generation(uuid, text)
to service_role;

-- ---------- 5. Form RPC (A4). Same body, signature, grants and not-found rules + ai_enabled ----------
drop function public.get_feedback_form(text);

-- Not found (null) when the branch, company, subcategory or category is inactive.
-- keywords = the branch's effective active keywords in position order (max 10); none = [].
-- ai_enabled = AI is switched on and the active provider has a saved key.
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
        where p.provider = a.active_provider and p.secret_id is not null
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
