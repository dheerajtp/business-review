# Plan 10 — Result (slice 02 evidence)

Environment: no database, Deno, browser or provider key. Only build, grep and static review are marked verified. Slice 01's result: see the `## Result` in `01-columns-rpcs-tests.md` (written in parallel).

| # | Acceptance item | Status | Evidence / manual steps |
| --- | --- | --- | --- |
| 1 | After the migration, `rls.sql` prints `ALL RLS TESTS PASSED` | not verified (needs DB; depends on 10/01, see its Result) | Manual: apply `supabase/migrations/20261124000001_ai_test_gate.sql`, then run `supabase/tests/rls.sql` against a local or throwaway database and look for `ALL RLS TESTS PASSED`. |
| 2 | Enable checkbox disabled until Test succeeds; enabled after | not verified (needs DB, deploy, browser, provider key) | Static: `AiSettingsPage.jsx` disables the checkbox unless the active provider has `has_key && last_test_ok`, with the hint "Run Test successfully on the active provider first."; Test reloads settings. `npm run build` passes. Manual: apply migration; `npx supabase functions deploy test-ai`; open `/admin/ai`, confirm checkbox is disabled, click Test on the active provider with a valid key, confirm "Tested OK" pill and the checkbox enables. |
| 3 | Changing model, base URL or key resets to "Not tested" and hides the customer button | not verified (needs DB, browser) | Static: pill reads `last_test_ok` from `get_ai_settings`; Save already reloads. Reset itself is in the migration (10/01). Manual: after a passing Test, change the model, Save, confirm "Not tested"; open the customer page and confirm no AI button until Test passes again. |
| 4 | Wrong model or key: Test fails, AI cannot be enabled, no AI button | not verified (needs DB, deploy, provider key) | Static: `test-ai` records `record_ai_test(provider, false)` on provider failures and empty replies, not on `no_key` or `list_models`; `set_ai_settings` error `provider not tested` maps to "Run Test successfully first.". Manual: deploy `test-ai`, save a wrong key or model, Test, confirm failure and that Enable stays off, and the review page `/f/{slug}` has no AI button. |
| 5 | Enabled provider failing with bad key/model switches the button off; outage/quota does not | not verified (needs DB, deploy, provider key) | Static: `generate-review` calls `record_ai_test(runtime.provider, false)` only when `e.kind` is `auth` or `model` (grep: single call, in `recordFailedTest`, invoked only under that condition). Manual: `npx supabase functions deploy generate-review --no-verify-jwt`; enable AI with a tested provider, then replace the key with a bad one directly in the provider console (or revoke it), click the AI button once (502), reload the page: button gone and `/admin/ai` shows "Not tested". Repeat with a quota or outage error: the button stays. |
| 6 | `SPEC.md` describes the test gate | verified | `grep -n "AI test gate" SPEC.md` finds the bullet in the AI section; `ai_providers` description now lists `last_test_ok` and `last_tested_at`. |

## Checks run
- `cd web && npm run build` passed.
- `grep -n record_ai_test supabase/functions/*/index.ts` shows one call in each function; in `generate-review` it is only reached via the `auth`/`model` condition.
- Response unchanged: by diff reading, every `json(...)` body and status in both functions is the same; the only additions are awaited best-effort `record_ai_test` calls (1 s cap, errors swallowed) before returning.
- Deno type-check, deploy, DB and browser checks: NOT RUN.
