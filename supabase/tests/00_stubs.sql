-- Minimal Supabase stand-ins so the migration runs on plain Postgres. Test-only.
create role anon nologin; create role authenticated nologin;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
end $$;
create schema auth;
create table auth.users (id uuid primary key default gen_random_uuid(), email text, last_sign_in_at timestamptz);
create function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to anon, authenticated;
grant usage on schema public to anon, authenticated, service_role;

-- Supabase Vault stand-in: secrets are stored in plain text here (test-only, no encryption).
create schema if not exists vault;
create table if not exists vault.secrets (
  id uuid primary key default gen_random_uuid(),
  name text,
  description text,
  secret text
);
create or replace function vault.create_secret(
  new_secret text, new_name text default null, new_description text default ''
) returns uuid language sql as
$$ insert into vault.secrets (secret, name, description) values (new_secret, new_name, new_description) returning id $$;
create or replace function vault.update_secret(
  secret_id uuid, new_secret text default null, new_name text default null, new_description text default null
) returns void language sql as
$$ update vault.secrets s
   set secret = coalesce(new_secret, s.secret),
       name = coalesce(new_name, s.name),
       description = coalesce(new_description, s.description)
   where s.id = secret_id $$;
create or replace view vault.decrypted_secrets as
  select id, name, description, secret as decrypted_secret from vault.secrets;
