# 06/01 — Schema, Vault storage, RPCs, form RPC flag, tests

Plan folder: [`00-README.md`](00-README.md) · Model: Opus · Prerequisites: none · Parallel with: none (schema runs alone first)

## Decisions you need
A1 (tables), A2 (admin RPCs, Vault), A3 (runtime RPCs), A4 (form flag), A6 (base URL guard rules), A11 (safety), A12 (tests) — run `grep -E '^\| (A1|A2|A3|A4|A6|A11|A12) ' 00-README.md`.

## Read first
- `supabase/migrations/20261120000001_company_keywords.sql`: `effective_keyword_ids(uuid)` (returns `keyword_id`, `pos`) and the current `get_feedback_form` body (you will drop and recreate it with the same signature and add one field).
- `supabase/migrations/20261118000001_keyword_library.sql`: `set_branch_keywords` for the role-check and error style to mirror.
- `supabase/tests/00_stubs.sql`: how `auth.uid()`, roles and `request.headers` are stubbed (add the vault stub here).
- `supabase/tests/rls.sql`: section style (`\echo`, `do $$ ... assert`), the `_ids` temp table, how roles are switched (`set local role`, `request.jwt.claim.sub`), and where the last sections ("user without profile") sit; add new sections before them.

## Scope (files you own)
- `supabase/migrations/20261121000001_ai_review.sql` (new)
- `supabase/tests/00_stubs.sql`
- `supabase/tests/rls.sql`

## Tasks
1. **Tables (A1).** Create the three tables, the checks, indexes and the single `ai_settings` row. Enable RLS, `revoke all ... from anon, authenticated`, add no policies and no grants.
2. **Admin RPCs (A2).** `set_ai_provider`, `clear_ai_provider_key`, `set_ai_settings`, `get_ai_settings` exactly as A2 (security definer, `set search_path = public`, role check `42501 'forbidden'`, `revoke all from public`, `grant execute to authenticated`). Use `vault.create_secret(key, 'ai_key_<provider>', 'AI provider key')` for a first key and `vault.update_secret(secret_id, key)` for a replacement. Implement the base-URL guard (A6) once as an internal immutable function `public.ai_valid_base_url(text) returns boolean` (revoked from public) and call it from `set_ai_provider`; reject with `22023 'invalid base url'`. Host extraction can use a regex on `^https://([^/:@?#]+)(:[0-9]+)?(/[^?#]*)?$` (no userinfo, no query/fragment); reject hosts equal to `localhost`, matching `^[0-9.]+$`, containing `:` or `[`, ending `.local` or `.internal`. Strip a trailing `/` before saving.
3. **Runtime RPCs (A3).** `get_ai_runtime`, `get_ai_provider_runtime`, `get_review_context`, `log_ai_generation`. Read the decrypted key from `vault.decrypted_secrets` by `secret_id`. `revoke all ... from public, anon, authenticated; grant execute ... to service_role`. `get_review_context` must use `effective_keyword_ids` joined to active keywords and keep label order equal to the request order (use `unnest(p_keyword_ids) with ordinality`); duplicates merged.
4. **Form RPC (A4).** `drop function public.get_feedback_form(text)` and recreate with the identical body and signature plus `'ai_enabled', coalesce((select s.is_enabled and exists (select 1 from ai_providers p where p.provider = s.active_provider and p.secret_id is not null) from ai_settings s), false)`. Keep grants (anon + authenticated) and all not-found rules.
5. **Stub (A12).** In `00_stubs.sql` add schema `vault` with `secrets(id uuid pk default gen_random_uuid(), name text, description text, secret text)`, `create_secret(new_secret text, new_name text default null, new_description text default '') returns uuid`, `update_secret(secret_id uuid, new_secret text default null, new_name text default null, new_description text default null) returns void`, and view `vault.decrypted_secrets(id, name, description, decrypted_secret)` selecting `secret as decrypted_secret`. Guard with `create schema if not exists` / `create or replace`. Ensure a `service_role` role exists in the stub (create it if missing, `nologin`).
6. **Tests (A12).** Add every check listed in A12. Use obvious fake keys (`test-key-1234`). Assert `get_ai_settings()::text` does not contain the fake key or the secret id. Keep every existing section passing.

## Done when
- Static review passes: statement order, every referenced object exists, `$$` balanced, new function signatures match A2/A3 exactly, `get_feedback_form` keeps its signature and grants. No database here: report DB checks NOT RUN; the user applies the migration after `20261120000001_company_keywords.sql` and needs Supabase Vault available.
- `grep -rn "test-key" supabase` finds fake keys only in `supabase/tests`.
- Append `## Result` (include the exact RPC signatures for the next slices).

## Result
Changed files:
- `supabase/migrations/20261121000001_ai_review.sql` (new): tables `ai_settings` (singleton row inserted), `ai_providers`, `ai_generation_log` (RLS on, `revoke all` from anon/authenticated, no policies/grants); internal `ai_valid_base_url(text)`; admin RPCs; service-role runtime RPCs; `get_feedback_form` dropped and recreated with `ai_enabled`.
- `supabase/tests/00_stubs.sql`: `service_role` role (created if missing, nologin, usage on `public`), `vault` stub (`secrets`, `create_secret`, `update_secret`, view `decrypted_secrets`).
- `supabase/tests/rls.sql`: new AI sections before "user without profile" (direct table access refused for anon/super/BA; admin RPCs 42501 for BA and anon; defaults; enable without key rejected; null/empty key keeps the key, new key updates the same Vault secret and `key_hint`; `get_ai_settings()::text` has no key or secret id; model/key/provider validation; base URL guard (http, localhost, IPv4, IPv6, .internal, .local, credentials, query, >300 chars); trailing slash stripped; settings validation; clear key deletes the secret and disables; runtime RPCs refused for anon/authenticated; service-role runtime shapes; `get_review_context` valid/inherited/empty/unknown slug/outside set/archived/null/11 ids/inactive branch/inactive company; `log_ai_generation` 6 then refuse, other client allowed, 7-day prune, daily limit; `ai_enabled` false by default, true when enabled with key, false when active provider has no key, false when disabled).

Exact signatures:
- `set_ai_provider(p_provider text, p_model text, p_base_url text, p_api_key text default null) returns void` (authenticated; super_admin else 42501 'forbidden')
- `clear_ai_provider_key(p_provider text) returns void` (authenticated; super_admin)
- `set_ai_settings(p_active_provider text, p_is_enabled boolean, p_daily_limit int) returns void` (authenticated; super_admin)
- `get_ai_settings() returns jsonb` → `{active_provider, is_enabled, daily_limit, providers:[{provider, model, base_url, has_key, key_hint, updated_at}]}` ordered by provider
- `get_ai_runtime() returns jsonb` → `{provider, model, base_url, api_key, daily_limit}` or null (service_role only)
- `get_ai_provider_runtime(p_provider text) returns jsonb` same shape or null (service_role only)
- `get_review_context(p_slug text, p_keyword_ids uuid[]) returns jsonb` → `{branch_id, company_name, branch_name, category_name, subcategory_name, labels:[text]}` or null (service_role only)
- `log_ai_generation(p_branch_id uuid, p_client_hash text) returns boolean` (service_role only)
- `get_feedback_form(p_slug text) returns jsonb` adds `ai_enabled boolean` (anon, authenticated)

Error codes/messages for the next slices: all validation errors are 22023 — `invalid provider`, `invalid model`, `invalid base url`, `invalid api key`, `invalid daily limit`, `provider has no key`, `unknown keyword` (also used for more than 10 distinct ids, per A3 wording). Forbidden = 42501 `forbidden`.

Notes:
- `log_ai_generation` matches the client with `is not distinct from`, so calls with a null hash share one bucket per branch; it locks the `ai_settings` row so concurrent calls count serially.
- `ai_generation_log.branch_id` is `not null`.
- `ai_valid_base_url` is also revoked from anon/authenticated explicitly (Supabase default privileges grant execute to them).

Checks:
- Static review (statement order, referenced objects exist, `$$` balanced: migration 20, stubs 8, rls 154; signatures match A2/A3; `get_feedback_form` keeps signature and anon+authenticated grants) → PASS
- `grep -rn "test-key" supabase` → only `supabase/tests/rls.sql` → PASS
- Applying the migration and running `00_stubs.sql` + migrations + `rls.sql` → NOT RUN (no postgres/psql/supabase CLI here; the user applies migrations). Real project needs Supabase Vault (`vault` schema) and runs this after `20261120000001_company_keywords.sql`.
