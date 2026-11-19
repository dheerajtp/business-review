# Plan 11 result: AI resilience

Evidence level: build, grep, static review and node checks with a mocked `fetch` only. No database, Deno, browser or provider key was available.

| # | Acceptance item | Status | Evidence / manual steps |
| --- | --- | --- | --- |
| 1 | After the migration, `rls.sql` prints `ALL RLS TESTS PASSED` | Not verified (needs DB; depends on slice 11/01, see its Result) | Steps: apply `supabase/migrations/20261125000001_ai_resilience.sql`, run `supabase/tests/rls.sql`, expect `ALL RLS TESTS PASSED`. |
| 2 | Gemini 503 on every call: Test retries, reports "provider is busy", card shows "Accepted, provider busy", AI can be enabled | Not verified (needs DB, deploy, provider) | Code: `test-ai` makes 4 calls (1/2/3 s waits), on final `unavailable` records `record_ai_test(provider,true,true)` and returns `{ok:true,busy:true}`; UI handles `data.busy` first and shows the pill from `last_test_busy`. Node mock confirms retries then `unavailable` (503 x3 + failing fallback case). Manual: apply migration; `npx supabase functions deploy test-ai`; on `/admin/ai` point at a model/endpoint returning 503 (or hit a busy model), press Test, check message, pill, and that "Enable AI reviews" becomes selectable. |
| 3 | Fallback saved: customer generation succeeds when primary keeps returning 503 and fallback answers | Partly verified (helper only) | Node mock: 503 x3 then fallback 200 gives `used_fallback: true`, fallback name in request URL. End to end not verified. Manual: save a Fallback model on `/admin/ai`, `npx supabase functions deploy generate-review --no-verify-jwt`, generate on `/f/{slug}`. |
| 4 | Short spike (503 then 200) hidden by retries | Verified at helper level (mock) | Node mock: 503,503,200 succeeds on call 3, `used_fallback:false`. Customer page check needs deploy. |
| 5 | Wrong key or model still fails Test, cannot be enabled, still switches the button off in customer use | Partly verified (static + mock) | Mock: 401 is not retried and skips the fallback; 429 not retried. `test-ai` records `(false,false)` for non-`unavailable` failures; `generate-review` still calls `record_ai_test(provider,false)` only for `auth`/`model`. DB gate behaviour not verified (needs DB/deploy). |
| 6 | Customer sees result or friendly failure within about 14 s | Not verified (needs browser, deploy) | Static: server deadline `TIMEOUT_MS = 12000`, client timeout in `FeedbackFormView.jsx` 14000 ms. Manual: with a provider that hangs, confirm the friendly failure (with ref code) appears at about 14 s at the latest. |
| 7 | `SPEC.md` describes retries, fallback and busy state | Verified (grep) | New "AI resilience (plan 11)" bullet, `ai_providers` columns `last_test_busy`, `fallback_model`, old "Timeout 8 s" line replaced. |

Also verified: `cd web && npm run build` passes; `grep -rn generateWithRetry supabase/functions` finds nothing.
Deploy order: apply the migration, `npx supabase functions deploy test-ai`, `npx supabase functions deploy generate-review --no-verify-jwt`, then the `/admin/ai` and customer-page checks.
