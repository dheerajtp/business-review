# 12/01 — Table, RPCs and tests

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 12/02 (disjoint files; contract fixed by L1–L3)

## Decisions you need
L1 (table), L2 (admin RPCs), L3 (sync_ai_models), L7 (tests) — run `grep -E '^\| (L1|L2|L3|L7) ' 00-README.md`.

## Read first
- `supabase/migrations/20261123000001_ai_error_log.sql`: table + RLS/revoke pattern, super-admin RPC role check (`42501 'forbidden'`, `current_app_role()`), service_role-only grant style.
- `supabase/migrations/20261125000001_ai_resilience.sql`: `ai_providers` columns (`model`, `fallback_model`) used by the "model in use" rule; `set_ai_fallback_model` for the validation style.
- `supabase/tests/rls.sql`: AI sections (search `ai_`, `service_role`, `reset role`); mirror their style. Remember: reads of closed tables must happen after `reset role` (or through an RPC), never as `authenticated`.

## Scope (files you own)
- `supabase/migrations/20261126000001_ai_models.sql` (new)
- `supabase/tests/rls.sql`

## Tasks
1. **Table (L1).** Create `ai_models` exactly as L1; enable RLS; `revoke all ... from anon, authenticated`; no policies, no grants; no seed rows.
2. **Admin RPCs (L2).** `list_ai_models(p_provider text default null) returns jsonb` (`coalesce(jsonb_agg(... order by provider, model_id), '[]'::jsonb)`), `add_ai_model(p_provider text, p_model_id text, p_label text default null) returns void`, `remove_ai_model(p_provider text, p_model_id text) returns void`, all `plpgsql security definer set search_path = public`, role check first (`42501 'forbidden'`), `revoke all on function ... from public, anon; grant execute ... to authenticated`. Model id pattern `^[A-Za-z0-9._:/-]+$` after `btrim`, length 1–100, else `22023 'invalid model id'`. `remove_ai_model` rules: `source = 'provider'` → `22023 'synced models cannot be removed'`; model equals `ai_providers.model` or `ai_providers.fallback_model` for that provider → `22023 'model in use'`; otherwise delete the manual row.
3. **Sync RPC (L3).** `sync_ai_models(p_provider text, p_models text[]) returns int` as L3: validate provider, cap 500 (`22023 'too many models'`), trim and pattern-filter ids (skip invalid), de-duplicate, upsert with `on conflict (provider, model_id) do update set source = 'provider', is_available = true, updated_at = now()`, then `update ... set is_available = false, updated_at = now() where provider = p_provider and source = 'provider' and not (model_id = any(<valid ids>))`; return the count of valid ids. `revoke all on function ... from public, anon, authenticated; grant execute ... to service_role`.
4. **Tests (L7).** Add one section with every check in L7, placed with the other AI sections; fake data only (`test-model-a`, etc.). Use `set local role service_role` for the sync tests and `reset role` before reading `ai_models` directly. Keep every other assertion.

## Done when
- Static review passes: statement order, every referenced object exists (`ai_providers.fallback_model` from the plan 11 migration), `$$` balanced, signatures and grants match L2/L3. No database here: report DB checks NOT RUN; the user applies the migration after `20261125000001_ai_resilience.sql`.
- No existing assertion in `rls.sql` is weakened and no test reads a closed table as `authenticated` or `anon`.
- Append `## Result`.

## Result
Files: `supabase/migrations/20261126000001_ai_models.sql` (new: table, `list_ai_models`, `add_ai_model`, `remove_ai_model`, `sync_ai_models`), `supabase/tests/rls.sql` (new L7 section inserted before the "user without profile" section; no existing assertion touched).
Checks: static review only (statement order, `$$` balance, signatures and grants vs L2/L3, `ai_providers.model`/`fallback_model` exist). DB migration and `rls.sql` run: NOT RUN (no database).
Facts: `list_ai_models` is `stable`; `add_ai_model` also raises `22023 'invalid label'` for a label over 100 chars and `22023 'invalid provider'`; `remove_ai_model` on an unknown row is a no-op. Tests read `ai_models` only after `reset role`, and read the saved gemini model through `get_ai_settings()`. Tests leave `ai_models` empty and the gemini fallback null.
