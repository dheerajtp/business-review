-- AI model list per provider: models synced from the provider (source 'provider') and
-- models added by hand (source 'manual'). Contains no keys and no customer data.
-- Access only through the RPCs below. Runs after 20261125000001_ai_resilience.sql.

-- ---------- 1. Table ----------
create table public.ai_models (
  provider text not null check (provider in ('gemini', 'anthropic', 'openai', 'custom')),
  model_id text not null check (char_length(model_id) between 1 and 100),
  label text null check (label is null or char_length(label) <= 100),
  is_available boolean not null default true,
  source text not null check (source in ('provider', 'manual')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (provider, model_id)
);

alter table public.ai_models enable row level security;
revoke all on public.ai_models from anon, authenticated;

-- ---------- 2. list_ai_models. Super Admin only ----------
create function public.list_ai_models(p_provider text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_provider is not null and p_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;

  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'provider', m.provider,
      'model_id', m.model_id,
      'label', m.label,
      'is_available', m.is_available,
      'source', m.source
    ) order by m.provider, m.model_id), '[]'::jsonb)
    from public.ai_models m
    where p_provider is null or m.provider = p_provider
  );
end $$;

-- ---------- 3. add_ai_model. Super Admin only ----------
create function public.add_ai_model(p_provider text, p_model_id text, p_label text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_id text := btrim(p_model_id);
  v_label text := nullif(btrim(p_label), '');
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_provider is null or p_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;
  if v_id is null or char_length(v_id) not between 1 and 100 or v_id !~ '^[A-Za-z0-9._:/-]+$' then
    raise exception 'invalid model id' using errcode = '22023';
  end if;
  if v_label is not null and char_length(v_label) > 100 then
    raise exception 'invalid label' using errcode = '22023';
  end if;

  insert into public.ai_models (provider, model_id, label, source)
  values (p_provider, v_id, v_label, 'manual')
  on conflict (provider, model_id) do update
    set is_available = true, updated_at = now();
end $$;

-- ---------- 4. remove_ai_model. Super Admin only; manual rows only ----------
create function public.remove_ai_model(p_provider text, p_model_id text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_id text := btrim(p_model_id);
  v_source text;
begin
  if public.current_app_role() is distinct from 'super_admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_provider is null or p_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;

  select source into v_source
  from public.ai_models
  where provider = p_provider and model_id = v_id;
  if not found then
    return;
  end if;

  if v_source = 'provider' then
    raise exception 'synced models cannot be removed' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.ai_providers
    where provider = p_provider and (model = v_id or fallback_model = v_id)
  ) then
    raise exception 'model in use' using errcode = '22023';
  end if;

  delete from public.ai_models
  where provider = p_provider and model_id = v_id and source = 'manual';
end $$;

revoke all on function public.list_ai_models(text), public.add_ai_model(text, text, text),
  public.remove_ai_model(text, text) from public, anon;
grant execute on function public.list_ai_models(text), public.add_ai_model(text, text, text),
  public.remove_ai_model(text, text) to authenticated;

-- ---------- 5. sync_ai_models. Service role only (Edge Function) ----------
create function public.sync_ai_models(p_provider text, p_models text[]) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_ids text[];
begin
  if p_provider is null or p_provider not in ('gemini', 'anthropic', 'openai', 'custom') then
    raise exception 'invalid provider' using errcode = '22023';
  end if;
  if coalesce(cardinality(p_models), 0) > 500 then
    raise exception 'too many models' using errcode = '22023';
  end if;

  select coalesce(array_agg(distinct t.id), '{}')
    into v_ids
  from (select btrim(x) as id from unnest(coalesce(p_models, '{}'::text[])) x) t
  where t.id is not null
    and char_length(t.id) between 1 and 100
    and t.id ~ '^[A-Za-z0-9._:/-]+$';

  insert into public.ai_models (provider, model_id, source, is_available)
  select p_provider, i, 'provider', true from unnest(v_ids) i
  on conflict (provider, model_id) do update
    set source = 'provider', is_available = true, updated_at = now();

  update public.ai_models
    set is_available = false, updated_at = now()
    where provider = p_provider and source = 'provider' and not (model_id = any(v_ids));

  return coalesce(cardinality(v_ids), 0);
end $$;

revoke all on function public.sync_ai_models(text, text[]) from public, anon, authenticated;
grant execute on function public.sync_ai_models(text, text[]) to service_role;
