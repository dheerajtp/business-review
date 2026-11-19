# 11/02 — Helper, both functions, admin UI, customer timeout, SPEC and acceptance evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 11/01 (disjoint files)

## Decisions you need
F5 (generateResilient), F6 (customer endpoint), F7 (test endpoint outcomes), F8 (admin UI), F9 (customer timeout), F11 (node checks), F12 (out of scope) — run `grep -E '^\| (F5|F6|F7|F8|F9|F11|F12) ' 00-README.md`. RPC contracts you call (F2–F4, being written in 11/01): `record_ai_test(p_provider, p_ok, p_busy)` via service role; `set_ai_fallback_model(p_provider, p_model)`; `get_ai_settings().providers[]` gains `fallback_model` and `last_test_busy`; `get_ai_runtime()` / `get_ai_provider_runtime()` gain `fallback_model`.

## Read first
- `supabase/functions/_shared/providers.js`: `generate()`, `generateWithRetry()` (to be replaced), `ProviderError` (fields `kind`, `status`, `detail`), `listModels()`.
- `supabase/functions/generate-review/index.ts`: the provider call, `TIMEOUT_MS`, the `catch` with `logError(...)` and the plan 10 `record_ai_test(..., false)` for `auth`/`model`.
- `supabase/functions/test-ai/index.ts`: the `action === 'test'` path, `recordTest`, `fail(e)` helper, the 8 s `TIMEOUT_MS`.
- `web/src/admin/AiSettingsPage.jsx`: provider card (Model input and datalist, `ProviderCard` state, Save handler, Test handler, status pills, `rpcError`).
- `web/src/customer/FeedbackFormView.jsx`: the 10 s `setTimeout` race in `generate()`.

## Scope (files you own)
`supabase/functions/_shared/providers.js`, `supabase/functions/test-ai/index.ts`, `supabase/functions/generate-review/index.ts`, `web/src/admin/AiSettingsPage.jsx`, `web/src/customer/FeedbackFormView.jsx`, an appended `air-` block in `web/src/styles.css`, `SPEC.md`, `docs/plans/11-ai-resilience/RESULT.md` (new).

## Tasks
1. **generateResilient (F5).** Implement as F5 in `providers.js`; abort-aware sleep (resolve early and throw the abort `ProviderError('timeout')` if `signal.aborted`); attach `model` to the rethrown error; remove `generateWithRetry` and update its importers.
2. **generate-review (F6).** Use `generateResilient({ provider, model, base_url, api_key, system, user, fallback_model: runtime.fallback_model, attempts: 3, delaysMs: [600, 1500], signal })`; `TIMEOUT_MS = 12000`; `logError` and the `record_ai_test(runtime.provider, false)` for `auth`/`model` use `e.model ?? runtime.model` where a model is logged; the `auth`/`model` switch-off still applies only to those kinds. Do not change any response body or status code.
3. **test-ai (F7).** Action `test`: `generateResilient` with `attempts: 4`, `delaysMs: [1000, 2000, 3000]`, `TIMEOUT_MS = 22000`, `fallback_model: runtime.fallback_model`. Success → `recordTest(admin, provider, true, false)`, respond `{ ok:true, sample, model_used, used_fallback }`. Failure kind `unavailable` → `recordTest(admin, provider, true, true)`, respond `{ ok:true, busy:true, status: e.status, detail: e.detail }` (omit undefined). Other failures → `recordTest(admin, provider, false, false)` and the existing `{ ok:false, reason, status?, detail? }`; empty reply stays `reason:'empty'`. Update `recordTest` to take `(admin, provider, ok, busy)` and send `p_busy`. Authentication, `no_key`, `list_models` unchanged.
4. **Admin UI (F8).** Add the "Fallback model (optional)" input to each card (same datalist as Model, `maxLength={100}`, placeholder "Another model to try if the first is busy"); Save calls `set_ai_provider` then `set_ai_fallback_model({ p_provider, p_model: value || null })`; show the three pill states and the Test messages from F8 (handle `data.busy` before `data.ok`); map `save the provider first`; keep everything else. Append `air-` CSS only if needed.
5. **Customer (F9).** Change the client timeout in `generate()` from 10000 to 14000 ms; nothing else in that file.
6. **Node checks (F11).** Scratchpad scripts only (not in the repo), mocked `fetch`; run every case in F11 and paste the outputs in Result.
7. **SPEC.md.** In the AI section describe: retries with backoff, the optional fallback model and when it is used, Test treating a busy provider as accepted ("Accepted, provider busy"), and the 12 s generation deadline; add `fallback_model` and `last_test_busy` to the `ai_providers` description.
8. **RESULT.md.** One row per acceptance checkbox in `00-README.md`: verified or "not verified (needs DB/deploy/provider key)" with evidence and exact manual steps (apply the migration, `npx supabase functions deploy test-ai`, `npx supabase functions deploy generate-review --no-verify-jwt`, then the `/admin/ai` and customer-page checks). Row 1 and DB rows depend on 11/01 running in parallel: mark not verified and reference its Result. Only build, grep, static and node/mock facts may be marked verified. Do not tick Status boxes for 11/01.

## Done when
- `cd web && npm run build` passes.
- `grep -rn "generateWithRetry" supabase/functions` finds nothing.
- All F11 node cases pass with the output pasted in Result.
- `generate-review` HTTP responses and status codes are unchanged (state how you checked by reading the diff).
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
STATUS: DONE

Changed: `supabase/functions/_shared/providers.js` (`generateResilient` replaces `generateWithRetry`; abort-aware backoff; `model` on rethrown error), `supabase/functions/generate-review/index.ts` (attempts 3, delays 600/1500, 12 s, fallback, logged model `e.model ?? runtime.model`), `supabase/functions/test-ai/index.ts` (attempts 4, 22 s for `test`; `list_models` keeps 8 s via `LIST_TIMEOUT_MS`; `recordTest(admin, provider, ok, busy)` sends `p_busy`; busy/success/empty outcomes), `web/src/admin/AiSettingsPage.jsx` (Fallback model input, `set_ai_fallback_model` after `set_ai_provider`, three pill states, busy/success messages, `save the provider first` mapping, card/global keys include fallback and busy fields), `web/src/customer/FeedbackFormView.jsx` (10000 to 14000 only; failureCode and ref code untouched), `SPEC.md`, `docs/plans/11-ai-resilience/RESULT.md`. No CSS added (not needed).

Checks:
- `cd web && npm run build` PASS
- `grep -rn generateWithRetry supabase/functions` no matches PASS
- Node F11 (scratchpad `/private/tmp/claude-501/-Users-dheerajtp-dev-business-review/58569f22-cc32-4d9c-9483-cfef5aed73d9/scratchpad/f11.mjs`, mocked fetch): PASS 503,503,200 on call 3; PASS 503x3 then fallback 200 (used_fallback, `/models/fb:` in URL); PASS 404 uses fallback; PASS 401 not retried/no fallback; PASS 429 not retried; PASS fallback equal to primary not tried; PASS failing fallback rethrows with fallback model; PASS aborted signal stops the waiting (kind timeout, under 1 s).
- generate-review responses/status codes unchanged: diff only touches import, TIMEOUT_MS, the provider call arguments/destructuring `{ text }`, and the logged model; all `json(...)` calls and statuses are untouched.
- Deno, DB, browser, provider: NOT RUN.

Notes: `recordFailedTest` in generate-review still sends only `p_ok:false` (relies on `p_busy` default in 11/01's RPC; the migration must give `p_busy` a default false). Not in this slice's visible contract, so check 11/01's Result.
