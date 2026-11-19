# 08/01 — Provider detail and redaction, list-models, one retry, admin UI, SPEC and acceptance evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: none

## Decisions you need
G1 (error detail and redaction), G2 (list_models), G3 (admin UI), G4 (retry), G5 (free-text model), G6 (safety) — run `grep -E '^\| (G1|G2|G3|G4|G5|G6) ' 00-README.md`.

## Read first
- `supabase/functions/_shared/providers.js`: `ProviderError`, `statusKind`, `postJson`, `generate()` (the three adapters), `openaiBase()`. You will add `status`/`detail` plumbing, `generateWithRetry`, and a `listModels()` export.
- `supabase/functions/test-ai/index.ts`: authentication block, body validation, `get_ai_provider_runtime` call, the `try { generate ... } catch` that builds `{ok:false, reason}`.
- `supabase/functions/generate-review/index.ts`: the `generate({...})` call and its catch (it must keep returning only `502 {error:'ai_failed'}` and fixed log lines).
- `supabase/functions/_shared/urlGuard.js` (`isValidBaseUrl`, `normalizeBaseUrl`).
- `web/src/admin/AiSettingsPage.jsx`: `TEST_REASONS`, the `test()` handler (the `supabase.functions.invoke('test-ai', ...)` block), the Model `Field`/input, the per-provider card state (`model`, `baseUrl`, `key`, `hasKey`).

## Scope (files you own)
`supabase/functions/_shared/providers.js`, `supabase/functions/test-ai/index.ts`, `supabase/functions/generate-review/index.ts`, `web/src/admin/AiSettingsPage.jsx`, `SPEC.md`, `docs/plans/08-ai-diagnostics-and-models/RESULT.md` (new).

## Tasks
1. **Detail and redaction (G1).** `ProviderError` constructor takes `(kind, { status, detail } = {})` and stores them as `this.status`, `this.detail` (message stays `provider_<kind>`). In `postJson`, on `!res.ok` read the body text (`await res.text()` inside try/catch, cap reading to the first 2000 chars), parse JSON and take `error.message` if it is a string, else the raw text; then `detail = redact(text, api_key)`. `redact(text, key)` collapses whitespace, replaces every occurrence of `key` (split/join, no regex special-char issues) and any `key=...` / `x-goog-api-key` style query fragment `([?&]key=)[^&\s"']+` with `***`, and truncates to 200 characters. Pass the api key into `postJson` for redaction. Never put the URL or headers into `detail`.
2. **test-ai (G1, G2).** Accept `action` (`'test'` default or `'list_models'`, anything else `400 {error:'Valid action required'}`). `test`: as today, but the catch returns `{ ok:false, reason, status: e.status, detail: e.detail }` (omit undefined fields) and an empty reply keeps `reason:'empty'`. `list_models`: call the new `listModels({ provider, base_url, api_key, signal })` from `providers.js` and return `{ ok:true, models }` or the same failure shape. Authentication and the `no_key` response stay exactly as they are.
3. **listModels (G2).** In `providers.js` export `listModels` with the three endpoint shapes from G2, `redirect: "error"`, same `ProviderError` mapping and redaction, base URL guard for `openai`/`custom`, result = unique sorted ids, max 200. Gemini: filter by `supportedGenerationMethods` including `generateContent`, strip `models/`. Return `[]` (not an error) when the list is empty.
4. **Retry (G4).** Export `generateWithRetry(args)`: call `generate(args)`; if it throws a `ProviderError` with `kind === "unavailable"` and `!args.signal?.aborted`, `await` 400 ms (abort-aware) and call `generate(args)` once more; rethrow anything else. `generate-review` imports and calls `generateWithRetry` in place of `generate`; its catch, responses and log lines are unchanged (do not read or log `status`/`detail`). `test-ai` keeps plain `generate`.
5. **Admin UI (G3, G5).** In `AiSettingsPage.jsx`: (a) failures from Test and from the new Load models show `TEST_REASONS[reason]` followed by ` (HTTP {status}: {detail})` when present (render as plain text, never HTML); (b) a "Load models" button next to Test, enabled only when `hasKey`, calling `supabase.functions.invoke('test-ai', { body: { provider, action: 'list_models' } })`; keep `models` in card state, give the Model input `list={`models-${meta.id}`}` and render `<datalist id=...>` with the ids; show "N models available" (or the failure) under the input in the same style as other hints; (c) the model stays free text, no validation against the list. Reuse the existing message/busy patterns; do not add dependencies or routes.
6. **SPEC.md.** Add one or two sentences to the AI section: the admin can load the provider's model list; Test shows the provider's status and message to the Super Admin only; customer generation retries once on a 5xx.
7. **Node checks (scratchpad only, nothing added to the repo).** With a mocked `fetch`, verify and paste the output in Result: (a) a 404 body `{"error":{"message":"models/x is not found"}}` gives `kind:'model'`, `status:404`, `detail` = that message; (b) a mock that echoes the key (`test-key-1234`) in the body and in a `?key=test-key-1234` fragment yields a `detail` with no `test-key-1234`; (c) `generateWithRetry` with 503 then 200 returns text after exactly 2 calls; 503, 503 throws `unavailable` after 2 calls; 400 throws after 1 call; (d) `listModels` for Gemini filters out a model without `generateContent` and strips `models/`; for OpenAI-style `{data:[{id:'b'},{id:'a'},{id:'a'}]}` gives `['a','b']`.
8. **RESULT.md.** One row per acceptance checkbox in `00-README.md`: verified or "not verified (needs deploy/provider key)" with exact manual steps (`npx supabase functions deploy test-ai`, `npx supabase functions deploy generate-review`, open `/admin/ai`, Load models, Test with a wrong model name, etc.). Only build, grep and node/mock facts may be marked verified. Do not tick Status boxes.

## Done when
- `cd web && npm run build` passes.
- `grep -n "detail\|status" supabase/functions/generate-review/index.ts` shows no use of provider `detail`/`status` in responses or logs.
- The four node checks in task 7 pass with the output pasted in Result.
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
Changed: `supabase/functions/_shared/providers.js` (ProviderError status/detail, redact, request/postJson/getJson, `generateWithRetry`, `listModels`), `supabase/functions/test-ai/index.ts` (action, failure shape), `supabase/functions/generate-review/index.ts` (uses `generateWithRetry`), `web/src/admin/AiSettingsPage.jsx` (failText, Load models, datalist), `SPEC.md`, `RESULT.md`. Built on the earlier same-day edits (statusKind, Gemini maxOutputTokens, `empty`, TEST_REASONS).

Checks:
- `cd web && npm run build` PASS (built).
- grep on generate-review: only the `json()` helper status; PASS.
- Node mock run (scratchpad):
```
a model 404 models/x is not found
b bad key *** at https://x/y?key=***&a=1 false
b2 raw *** ?key=*** false
c1 hi 2
c2 unavailable 2
c3 model 1
d1 [ 'a', 'b' ]
d2 [ 'a', 'b' ]
d3 []
```
Not run: Deno, deploy, real providers. Note: the retry shares the caller's single AbortController, so the 8 s deadline covers both attempts.
