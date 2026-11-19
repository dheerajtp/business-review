# Plan 09 result: AI error log

Environment: no database, Deno, browser or provider key. Only the web build, greps and static review were run. DB rows depend on slice 09/01 (migration and `rls.sql`, written in parallel); see its Result in `01-table-rpcs-tests.md`.

Manual steps for every "not verified" row: (1) apply `supabase/migrations/20261123000001_ai_error_log.sql`; (2) `npx supabase functions deploy generate-review`; (3) on `/admin/ai` set a wrong model name for the active provider and Save; (4) open a customer `/f/{slug}`, pick keywords, click "Write my review with AI"; (5) return to `/admin/ai` and click Refresh on "Recent AI errors".

| # | Acceptance item | Status | Evidence / steps |
| --- | --- | --- | --- |
| 1 | `rls.sql` prints `ALL RLS TESTS PASSED`; no direct read of `ai_error_log` | Not verified (needs DB; depends on 09/01) | Run `supabase/tests/rls.sql` after applying the migration; see 09/01 Result. |
| 2 | Wrong model adds a `provider` row with provider, model, status, message; customer sees only the generic text | Not verified (needs DB, deploy, provider key) | Static: provider `catch` calls `logError` with stage `provider`, `runtime.provider`, `runtime.model`, `e.kind`, `e.status`, `e.detail`; response still `json({error:"ai_failed"},502)`. Customer UI untouched. Manual steps above. |
| 3 | Key never in stored or displayed detail; no prompt, review text or customer data stored | Partly verified (static) | `logError` only takes stage, provider, model, kind, status, detail; no call site passes `api_key`, `system`, `user`, `text`, `review`, `slug` or `keyword_ids`. `detail` is the plan 08 redacted value. Stored-row check needs DB: after step 4 confirm the row contains no key. |
| 4 | Business Admin cannot call `get_ai_errors` or `clear_ai_errors` | Not verified (needs DB; depends on 09/01) | Covered by `rls.sql` (09/01). Manual: sign in as Business Admin and call both RPCs, expect `42501`. UI shows "Only a Super Admin can view this." for `forbidden`. |
| 5 | Refresh and Clear work; at most 200 rows | Not verified (needs DB, browser) | Static: Refresh calls `log.reload`; Clear opens `ConfirmDialog`, calls `clear_ai_errors`, reloads. Row cap is in `log_ai_error` (09/01), tested in `rls.sql`. `cd web && npm run build` passes. |
| 6 | Logging failure never changes the customer response | Verified statically (not run) | `logError` wraps the RPC in try/catch/finally, races a 1 s timeout, returns nothing. Diff shows only added `await logError(...)` lines and a block form for the `!runtime` branch; every `json(...)` body and status and every `console` line is unchanged. Runtime check needs Deno and deploy. |
| 7 | `SPEC.md` describes the error log and who can see it | Verified | `SPEC.md` has the `ai_error_log` data model entry and an "AI error log (plan 09)" bullet (Super Admin only, `/admin/ai`). |

Not ticked: Status boxes for 09/01 and 09/02 are left for the orchestrator.
