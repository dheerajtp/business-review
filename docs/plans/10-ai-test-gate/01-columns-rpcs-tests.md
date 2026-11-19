# 10/01 — Columns, RPCs, gates and tests

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 10/02 (disjoint files; contract fixed by T1–T6)

## Decisions you need
T1 (columns), T2 (record_ai_test), T3 (reset on change), T4 (enable gate), T5 (form flag), T6 (settings read), T10 (tests) — run `grep -E '^\| (T1|T2|T3|T4|T5|T6|T10) ' 00-README.md`.

## Read first
- `supabase/migrations/20261121000001_ai_review.sql`: `set_ai_provider` (change detection: you must compare the new model, base_url and key against the stored row), `clear_ai_provider_key`, the `get_feedback_form` body (copy it, the latest definition is here unless a later migration redefined it: `grep -ln "get_feedback_form" supabase/migrations/*.sql`).
- `supabase/migrations/20261122000001_remove_ai_limits.sql`: current `set_ai_settings(text, boolean)` and `get_ai_settings()` bodies (copy these, they are the latest).
- `supabase/migrations/20261123000001_ai_error_log.sql`: grant/revoke style for service_role-only functions.
- `supabase/tests/rls.sql`: all AI sections (search `ai_`, `set_ai_settings`, `ai_enabled`, `service_role`); existing assertions that enable AI must now call `record_ai_test` first.

## Scope (files you own)
- `supabase/migrations/20261124000001_ai_test_gate.sql` (new)
- `supabase/tests/rls.sql`

## Tasks
1. **Columns (T1).** `alter table public.ai_providers add column last_test_ok boolean not null default false, add column last_tested_at timestamptz null;`
2. **record_ai_test (T2).** As T2 (`plpgsql`, validate provider against the four values, `update ... where provider = p_provider`). `revoke all on function ... from public, anon, authenticated; grant execute ... to service_role`.
3. **Reset on change (T3).** `create or replace function public.set_ai_provider(...)` with the identical signature and rules as today, plus: read the existing row (`for update`) before the upsert; set `last_test_ok = false, last_tested_at = null` when the model differs, the base_url differs (`is distinct from`), or a non-empty `p_api_key` is supplied; otherwise keep the stored flags. A first-time insert starts as `false`. Same for `clear_ai_provider_key` (reset both columns). Keep the grants exactly as before.
4. **Enable gate (T4).** `create or replace function public.set_ai_settings(p_active_provider text, p_is_enabled boolean)` (same signature, same role/provider checks): when enabling, the existing "provider has no key" check stays first, then require `last_test_ok` for the active provider else `raise exception 'provider not tested' using errcode = '22023'`. Also apply the check when `p_active_provider` differs from the stored active provider while the stored `is_enabled` is true and the call keeps it enabled (the call enables, so the same enabling rule covers it). Disabling is always allowed. Keep grants.
5. **Form flag (T5).** `drop function public.get_feedback_form(text)` and recreate with the identical body and signature, changing only `ai_enabled` to also require `p.last_test_ok`. Re-apply `revoke all ... from public; grant execute ... to anon, authenticated`.
6. **Settings read (T6).** `drop function public.get_ai_settings()` and recreate it with `last_test_ok` and `last_tested_at` added to each `providers` entry; same grant (`authenticated`, revoke from public/anon); output must never include a key or `secret_id`.
7. **Tests (T10).** Add every check listed in T10 and adjust existing AI assertions that enable AI (call `select record_ai_test('<provider>', true)` as `service_role` first, using the `set local role service_role` pattern already used for the runtime RPC tests). Fake keys only (`test-key-1234`). Keep every other assertion.

## Done when
- Static review passes: statement order, drop/create pairs use exact current signatures, `$$` balanced, grants match the originals, nothing else in `set_ai_provider`, `set_ai_settings`, `get_feedback_form`, `get_ai_settings` changed besides T3–T6. No database here: report DB checks NOT RUN; the user applies the migration after `20261123000001_ai_error_log.sql`.
- `grep -n "provider not tested" supabase/migrations/20261124000001_ai_test_gate.sql supabase/tests/rls.sql` shows both.
- Append `## Result`.

## Result
- Added `supabase/migrations/20261124000001_ai_test_gate.sql`: columns (T1), `record_ai_test` (T2, service_role only), `set_ai_provider` / `clear_ai_provider_key` reset-on-change (T3, `create or replace`, grants preserved), `set_ai_settings(text, boolean)` gate (T4, key check first, then `provider not tested`), `get_feedback_form` drop/recreate with `last_test_ok` (T5), `get_ai_settings` drop/recreate with the two fields (T6).
- `supabase/tests/rls.sql`: existing enabling calls now record a passed test first; new T10 section after the "disabled = false" form check.
- Checks: `grep "provider not tested"` shows both files; `$$` balanced (12). DB run NOT RUN (no database; user applies migrations).
- Facts: `get_ai_settings().providers[]` now has `last_test_ok`, `last_tested_at`; `record_ai_test(p_provider, p_ok)` returns void.
