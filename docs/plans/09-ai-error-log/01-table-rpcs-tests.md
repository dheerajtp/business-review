# 09/01 — Table, RPCs and tests

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 09/02 (disjoint files; contract fixed by H1–H3)

## Decisions you need
H1 (table), H2 (log_ai_error), H3 (get_ai_errors, clear_ai_errors), H7 (tests) — run `grep -E '^\| (H1|H2|H3|H7) ' 00-README.md`.

## Read first
- `supabase/migrations/20261121000001_ai_review.sql`: the `ai_*` tables' RLS/revoke pattern, `get_ai_settings` (role check `42501 'forbidden'`, `current_app_role()`), and the `service_role`-only runtime RPCs' revoke/grant lines to copy.
- `supabase/migrations/20261122000001_remove_ai_limits.sql`: current shapes (nothing here may be changed).
- `supabase/tests/rls.sql`: search for `ai_` and `service_role` to find the AI test sections, how roles are switched (`set local role`, `request.jwt.claim.sub`), and where to add a new section before the "user without profile" section.

## Scope (files you own)
- `supabase/migrations/20261123000001_ai_error_log.sql` (new)
- `supabase/tests/rls.sql`

## Tasks
1. **Table (H1).** Create `ai_error_log` with the checks and the index exactly as H1; enable RLS; `revoke all ... from anon, authenticated`; no policies, no grants.
2. **log_ai_error (H2).** `log_ai_error(p_stage text, p_provider text, p_model text, p_kind text, p_status int, p_detail text) returns void`, `language plpgsql security definer set search_path = public`. Validate `p_stage` against the five allowed values (`raise exception 'invalid stage' using errcode = '22023'`), cut `p_kind` to 30 and `p_detail` to 200 characters (`left(...)`), cut `p_provider` and `p_model` to 100, insert, then `delete from ai_error_log where id in (select id from ai_error_log order by created_at desc, id desc offset 200)`. `revoke all on function ... from public, anon, authenticated; grant execute ... to service_role`.
3. **Read and clear (H3).** `get_ai_errors(p_limit int default 20) returns jsonb` (role check `42501 'forbidden'`, limit `least(greatest(coalesce(p_limit, 20), 1), 100)`, `coalesce(jsonb_agg(... order by created_at desc, id desc), '[]'::jsonb)` of `{id, created_at, stage, provider, model, kind, status, detail}`), and `clear_ai_errors() returns void` (same role rule, `delete from ai_error_log`). Both `security definer`, `set search_path = public`, `revoke all from public, anon`, `grant execute to authenticated`.
4. **Tests (H7).** Add a section covering every check in H7. For the 200-row cap insert 205 rows through `log_ai_error` as `service_role` and assert `count(*) = 200` and that the oldest 5 are gone. Use obvious fake text, no keys.

## Done when
- Static review passes: statement order, every referenced object exists, `$$` balanced, signatures match H2/H3 exactly, grants match (service_role only for `log_ai_error`; authenticated for the two admin RPCs). No database here: report DB checks NOT RUN; the user applies the migration after `20261122000001_remove_ai_limits.sql`.
- No existing assertion in `rls.sql` is weakened.
- Append `## Result`.

## Result
Files: `supabase/migrations/20261123000001_ai_error_log.sql` (new: table + index + RLS/revoke, `log_ai_error` service_role only, `get_ai_errors(int)` and `clear_ai_errors()` super admin via authenticated grant); `supabase/tests/rls.sql` (new section before "user without profile": direct table/RPC access closed for anon and authenticated, service role write, invalid/null stage 22023, truncation 100/100/30/200, cap of 200 from 205 calls, 42501 for business admin and anon, newest first, limit clamp 0/-5/null/1000, clear).
Checks: static review only (statement order, signatures, grants, `$$` balance). All DB checks NOT RUN (no database).
Note: the 205 cap test uses psql `\gexec` so each call is its own transaction; this gives distinct `now()` values and a deterministic "oldest 5 gone" assertion. No existing assertion changed.
