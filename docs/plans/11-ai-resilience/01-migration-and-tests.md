# 11/01 — Migration and tests

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 11/02 (disjoint files; contract fixed by F1–F4)

## Decisions you need
F1 (columns), F2 (set_ai_fallback_model), F3 (record_ai_test 3-arg, resets), F4 (reads), F10 (tests) — run `grep -E '^\| (F1|F2|F3|F4|F10) ' 00-README.md`.

## Read first
- `supabase/migrations/20261124000001_ai_test_gate.sql`: current `record_ai_test(text, boolean)`, `set_ai_provider(text,text,text,text)`, `clear_ai_provider_key(text)`, `set_ai_settings`, `get_ai_settings()` (copy these bodies; they are the latest).
- `supabase/migrations/20261122000001_remove_ai_limits.sql`: current `get_ai_runtime()` and `get_ai_provider_runtime(text)` (copy; they are the latest unless a later migration redefined them: `grep -ln "get_ai_runtime\|get_ai_provider_runtime" supabase/migrations/*.sql`).
- `supabase/migrations/20261123000001_ai_error_log.sql`: style for service_role-only and super-admin RPC grants.
- `supabase/tests/rls.sql`: all AI sections (search `ai_`, `record_ai_test`, `set_ai_provider`, `get_ai_settings`, `get_ai_runtime`, `service_role`).

## Scope (files you own)
- `supabase/migrations/20261125000001_ai_resilience.sql` (new)
- `supabase/tests/rls.sql`

## Tasks
1. **Columns (F1).** `alter table public.ai_providers add column fallback_model text null check (...), add column last_test_busy boolean not null default false;` exactly as F1.
2. **set_ai_fallback_model (F2).** As F2 (`plpgsql`, role check `42501 'forbidden'` via `current_app_role()`, provider validation, trim, 1–100, blank/null clears, `22023 'save the provider first'` when no row). `revoke all ... from public, anon; grant execute ... to authenticated`.
3. **record_ai_test (F3).** `drop function public.record_ai_test(text, boolean);` then `create function public.record_ai_test(p_provider text, p_ok boolean, p_busy boolean default false) returns void` with the stated semantics; `revoke all ... from public, anon, authenticated; grant execute ... to service_role`.
4. **Resets (F3).** `create or replace` `set_ai_provider(p_provider text, p_model text, p_base_url text, p_api_key text default null)` and `clear_ai_provider_key(p_provider text)` with identical signatures and bodies from the plan 10 migration, adding `last_test_busy = false` wherever `last_test_ok` is reset. Do not change anything else in them; keep their grants (create or replace preserves them).
5. **Reads (F4).** `drop function public.get_ai_settings();` `drop function public.get_ai_runtime();` `drop function public.get_ai_provider_runtime(text);` then recreate each with the current body plus the new fields (`fallback_model`, and `last_test_busy` in `get_ai_settings` providers entries). Re-apply `revoke all ... from public, anon, authenticated` and the same `grant execute` as today (authenticated for `get_ai_settings`; service_role only for the two runtime functions). Do not return `secret_id`; the runtime functions keep returning `api_key` as they do now.
6. **Tests (F10).** Add every check in F10; adapt existing calls: `record_ai_test('<p>', true)` keeps working through the default, but any test that asserted the exact 2-argument signature must be updated. Use `\echo` sections and fake keys (`test-key-1234`) only. Keep every other assertion.

## Done when
- Static review passes: statement order (columns before functions that use them; drops before creates; the old 2-arg `record_ai_test` is dropped exactly once), exact current signatures in every drop, `$$` balanced, grants match. No database here: report DB checks NOT RUN; the user applies the migration after `20261124000001_ai_test_gate.sql`.
- `grep -n "record_ai_test" supabase/tests/rls.sql` shows no call that depends on the dropped 2-arg overload being distinct.
- Append `## Result`.

## Result
- Added `supabase/migrations/20261125000001_ai_resilience.sql`: columns (F1), `set_ai_fallback_model` (F2), 2-arg `record_ai_test` dropped and 3-arg created (service_role only, F3), `set_ai_provider`/`clear_ai_provider_key` reset `last_test_busy` (F3), `get_ai_settings`/`get_ai_runtime`/`get_ai_provider_runtime` dropped and recreated with `fallback_model` (+ `last_test_busy` in settings) and the same grants (F4).
- `supabase/tests/rls.sql`: new sections inserted before the `ai_error_log` section (F10). Existing 2-arg calls untouched (work via the default).
- Checks: static review only (drop order, signatures, grants, `$$` balance, new tests avoid direct reads of closed AI tables under authenticated). DB run NOT RUN (no database; user applies after 20261124000001).
- Note: existing plan-10 assertions in rls.sql (about lines 1250, 1276) read `ai_settings` directly as authenticated, which the closed-table grants would refuse; not changed (pre-existing, not mine).
- Fix (static, rls.sql ~1250/1276/1278): the three direct `ai_settings` reads under `authenticated` in the "enabling needs a passed test" section now read through `get_ai_settings()` (`is_enabled`, `active_provider`), keeping the same expected values; no other direct AI-table reads under anon/authenticated were found in the file.
