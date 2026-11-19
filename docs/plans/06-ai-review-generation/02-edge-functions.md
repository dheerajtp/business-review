# 06/02 — Edge Functions: generate-review, test-ai, provider adapters

Plan folder: [`00-README.md`](00-README.md) · Model: Opus · Prerequisites: 06/01 · Parallel with: 06/03, 06/04 (disjoint files; they only call the contracts fixed in A3–A10)

## Decisions you need
A3 (runtime RPC names and shapes), A5 (generate-review), A6 (adapters and URL guard), A7 (prompt), A8 (test-ai), A11 (safety) — run `grep -E '^\| (A3|A5|A6|A7|A8|A11) ' 00-README.md`.

## Read first
- `supabase/functions/create-business-admin/index.js`: CORS headers, `json()` helper, caller authentication (`admin.auth.getUser(token)` then `profiles.role`), body validation style, `Deno.serve`, `npm:@supabase/supabase-js@2` import. Mirror this exactly for `test-ai`.

## Scope (files you own)
`supabase/functions/generate-review/index.ts` (new), `supabase/functions/test-ai/index.ts` (new), `supabase/functions/_shared/providers.js` (new), `supabase/functions/_shared/prompt.js` (new), `supabase/functions/_shared/urlGuard.js` (new). Plain JavaScript, no new dependencies besides the Supabase client already used.

## Tasks
1. **urlGuard.js (A6).** `isValidBaseUrl(url)` mirroring the SQL rules (https only, ≤ 300 chars, no credentials/query/fragment, host not `localhost`, not an IPv4/IPv6 literal, not ending `.local`/`.internal`) and `normalizeBaseUrl(url)` stripping a trailing `/`.
2. **providers.js (A6).** `generate({ provider, model, base_url, api_key, system, user, maxTokens = 300, signal })` with the four adapters exactly as A6 (endpoints, headers, bodies, response extraction). Call `isValidBaseUrl` before using a `base_url` (throw `ProviderError('model')`-style typed errors). Export `class ProviderError extends Error` with a `kind` of `auth | model | network | timeout | unknown`, mapped: HTTP 401/403 → `auth`, 400/404 → `model`, 429/5xx/other → `unknown`, `fetch` throw → `network`, `AbortError` → `timeout`. Never include the response body, URL or key in `message`.
3. **prompt.js (A7).** `buildPrompt({ company_name, branch_name, category_name, subcategory_name, rating, labels })` returning `{ system, user }` with the exact system text and user line format from A7, and `sanitizeReview(text)` implementing the sanitize rules (returns '' when empty).
4. **generate-review (A5).** Implement the flow and status codes of A5. Validate: JSON body ≤ 4096 bytes (read text, check length, then parse), `slug` string 1–64 chars, `rating` integer 1–5, `keyword_ids` array of ≤ 10 UUID strings. Use a service-role client (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) only to call `rpc('get_review_context')`, `rpc('get_ai_runtime')`, `rpc('log_ai_generation')`. `client_hash`: SHA-256 (`crypto.subtle.digest`) of the first address in `x-forwarded-for`, hex, first 32 chars. 8 s timeout via `AbortController`. Map RPC error code `22023` to `400 {error:'invalid_keywords'}`. Response only `{review}`; errors `{error}` with the codes in A5. Do not `console.log` keys, prompts or provider responses (log only a short event name and status).
5. **test-ai (A8).** Authenticate like `create-business-admin`; body `{ provider }` (one of the four); `get_ai_provider_runtime` null → `{ok:false, reason:'no_key'}`; else call the adapter with the sample context and return `{ok:true, sample}` or `{ok:false, reason: error.kind}`.
6. **Self-check.** Do not add files outside Scope. Verify the pure helpers (`isValidBaseUrl`, `buildPrompt`, `sanitizeReview`) with a `node` one-liner or a temporary script in the scratchpad directory (not in the repo) and paste the results in Result.

## Done when
- Static review passes: imports resolve, every RPC name and argument matches A3, status codes match A5, no secret or prompt reaches a log or a response. No Deno or network here: report runtime checks NOT RUN.
- `node` check of the pure helpers shows: `https://api.example.com/v1/` valid; `http://x.com`, `https://localhost/v1`, `https://10.0.0.1/v1`, `https://[::1]/`, `https://user:pw@x.com/`, `https://svc.internal/` all invalid; `sanitizeReview('  "Great!"  \n\n ok ')` → `Great! ok`.
- `grep -rn "console.log" supabase/functions/generate-review supabase/functions/test-ai` shows no key/prompt data.
- Append `## Result` including the deploy commands (`supabase functions deploy generate-review`, `supabase functions deploy test-ai`) for the runbook.

## Result
Changed files (all new):
- `supabase/functions/_shared/urlGuard.js`: `isValidBaseUrl(url)` (same regex and host rules as SQL `ai_valid_base_url`), `normalizeBaseUrl(url)` (strips trailing `/`).
- `supabase/functions/_shared/prompt.js`: `buildPrompt({...})` → `{system, user}` (A7 text verbatim; zero labels → `Keywords: none`), `sanitizeReview(text)` (unwraps quotes around the whole text and each line, collapses whitespace, cuts to 600; '' on empty).
- `supabase/functions/_shared/providers.js`: `generate({...})` with the four A6 adapters and `class ProviderError` (`kind`: auth | model | network | timeout | unknown; message is only `provider_<kind>`). Invalid/missing custom base URL, unknown provider, empty model/key → `model`.
- `supabase/functions/generate-review/index.ts`: A5 flow. Status/error codes: 405 `method_not_allowed`, 413 `too_large` (Content-Length or byte length of the text > 4096), 400 `invalid_input`, 400 `invalid_keywords` (RPC 22023), 404 `not_found`, 503 `ai_unavailable`, 429 `rate_limited`, 502 `ai_failed`, 500 `server_error` (unexpected RPC error), 200 `{review}`.
- `supabase/functions/test-ai/index.ts`: auth copied from `create-business-admin` (401 `Not signed in`, 403 `Forbidden`); 400 `Valid provider required`; 200 `{ok:false, reason:'no_key'}` / `{ok:true, sample}` / `{ok:false, reason:<kind>}` (empty output → `unknown`); 500 if the RPC itself errors.

Checks:
- node helper check (scratchpad script, mocked fetch, no network) → PASS: `https://api.example.com/v1/` true; `http://x.com`, `https://localhost/v1`, `https://10.0.0.1/v1`, `https://[::1]/`, `https://user:pw@x.com/`, `https://svc.internal/`, `https://a.local/`, query, fragment all false; `sanitizeReview('  "Great!"  \n\n ok ')` → `Great! ok`; 700 chars → 600; user line `Business: Acme (Main); Type: Food / Cafe; Rating: 4 out of 5; Keywords: a, b`. Error mapping 401/403→auth, 400/404→model, 429/500→unknown, fetch throw→network, AbortError→timeout. Request shapes for openai (`max_completion_tokens`, no temperature), custom (`max_tokens`, `temperature: 0.8`, trailing slash stripped), gemini URL, anthropic headers as A6.
- `grep -rn "console.log" supabase/functions/generate-review supabase/functions/test-ai` → none; only `console.error/warn` with fixed event names and the error kind → PASS.
- Static review: RPC names/args match 01 Result (`get_review_context(p_slug, p_keyword_ids)`, `get_ai_runtime()`, `log_ai_generation(p_branch_id, p_client_hash)`, `get_ai_provider_runtime(p_provider)`); imports are relative `../_shared/*.js` + `npm:@supabase/supabase-js@2` → PASS.
- Deno runtime / `supabase functions serve` / real provider calls → NOT RUN (no Deno, network or database here).

Notes for next slices:
- `client_hash` is the SHA-256 of the first `x-forwarded-for` entry, trimmed; with no header it hashes the empty string (a constant), so header-less callers share one bucket per branch.
- 06/04 should treat any non-200 as "draft failed"; the distinct codes above are available if it wants specific messages (429 `rate_limited`, 503 `ai_unavailable`).
- generate-review keeps default JWT verification (anon key works via `supabase.functions.invoke`).

Deploy (runbook):
```
supabase functions deploy generate-review
supabase functions deploy test-ai
```

- Follow-up fix: `_shared/providers.js` `postJson` fetch now passes `redirect: "error"`; a redirect makes fetch throw, which maps to `ProviderError("network")` via the existing catch (checked with a mocked fetch: option is `error`, kind `network`).
