# 07/01 — Migration and tests

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 07/02 (disjoint files)

## Decisions you need
R1 (migration steps and signatures), R5 (tests), R6 (safety note, for context) — run `grep -E '^\| (R1|R5|R6) ' 00-README.md`.

## Read first
- `supabase/migrations/20261121000001_ai_review.sql`: `ai_settings` (with `daily_limit`), `ai_generation_log`, `set_ai_settings` (3 args), `get_ai_settings`, `get_ai_runtime`, `get_ai_provider_runtime`, `log_ai_generation`, and the grants/revokes at the end of each block. Copy their bodies, minus everything about `daily_limit`.
- `supabase/tests/rls.sql`: search for `ai_`, `daily`, `log_ai_generation`, `set_ai_settings(` to find every AI section; keep the style (`\echo`, `do $$ ... assert`).

## Scope (files you own)
- `supabase/migrations/20261122000001_remove_ai_limits.sql` (new)
- `supabase/tests/rls.sql`

## Tasks
1. **Migration (R1).** Header comment (what it removes and that existing log rows are dropped). Steps in the R1 order. Drop with exact current signatures: `drop function public.log_ai_generation(uuid, text);`, `drop table public.ai_generation_log;`, `drop function public.set_ai_settings(text, boolean, int);` then `create function public.set_ai_settings(p_active_provider text, p_is_enabled boolean) returns void` (same role check, provider validation, "provider has no key" rule and grants as before, no limit argument); `alter table public.ai_settings drop column daily_limit;` (do this **after** the functions that reference it are dropped or replaced); then `create or replace` (or drop + create when the return type or signature requires it) `get_ai_settings()`, `get_ai_runtime()`, `get_ai_provider_runtime(text)` without `daily_limit`, re-applying `revoke all ... from public, anon, authenticated` and the same `grant execute` as in the original migration (authenticated for `get_ai_settings`; service_role only for the two runtime functions). Do not touch `get_feedback_form`, `get_review_context`, `set_ai_provider`, `clear_ai_provider_key` or `ai_valid_base_url`.
2. **Tests (R5).** Remove the `log_ai_generation` and daily-limit assertions and fixtures, change every `set_ai_settings` call to two arguments, add the "no daily_limit in `get_ai_settings()::text` / runtime output" and "table and function no longer exist" assertions (`to_regclass('public.ai_generation_log') is null`; `not exists (select 1 from pg_proc where proname = 'log_ai_generation')`). Keep every other AI assertion and every non-AI section untouched. If any later fixture inserted into `ai_generation_log`, remove it.

## Done when
- Static review passes: drop/create order has no dangling reference (nothing still uses `daily_limit` or `ai_generation_log` after the migration), `$$` balanced, grants match the original, no other function changed.
- `grep -n "daily_limit\|ai_generation_log\|log_ai_generation" supabase/tests/rls.sql` shows only the new "no longer exists" assertions.
- No database here: report DB checks NOT RUN; the user applies the migration after `20261121000001_ai_review.sql`.
- Append `## Result`.

## Result
Changed: `supabase/migrations/20261122000001_remove_ai_limits.sql` (new), `supabase/tests/rls.sql`.
- Migration order: drop log_ai_generation, drop ai_generation_log, drop+create 2-arg set_ai_settings (grant authenticated), drop get_ai_settings/get_ai_runtime/get_ai_provider_runtime, drop column daily_limit, recreate the three without daily_limit with original grants.
- Tests: removed ai_generation_log from the closed-table list and log_ai_generation from the runtime-closed list, deleted the log/limit section and limit validation asserts, all set_ai_settings calls now 2 args, added no-daily_limit asserts (settings, both runtime RPCs) and a "dropped" section (table, function, column, 3-arg overload).
- Checks: static grep of rls.sql shows only the new assertions; `$$` count in migration is even (8). DB apply and rls.sql run: NOT RUN (no database).
