# 08 — AI provider diagnostics and model picker

Master plan: none (`SPEC.md` gets a short update in the slice) · Builds on and amends: [`../06-ai-review-generation/00-README.md`](../06-ai-review-generation/00-README.md) (relaxes A6/A8: the provider's error text may be shown to the Super Admin in Test only; adds model listing)

## Goal
- When Test or generation fails, the Super Admin sees the real reason (HTTP status and the provider's own message), not just "temporarily unavailable".
- The Super Admin picks the model from the list the provider actually offers for the saved key, instead of typing a name from memory.
- Customers get one automatic retry when the provider answers with a temporary 5xx.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| G1 | **Error detail for Test only.** `ProviderError` (in `supabase/functions/_shared/providers.js`) gains optional `status` (HTTP status number) and `detail` (string). `detail` is the provider's error message: for JSON bodies `error.message` (Gemini, OpenAI, Anthropic all use this shape), otherwise the first 200 characters of the text body; truncated to 200 characters, whitespace collapsed, and **redacted**: every occurrence of the API key and of a `key=` query value is replaced with `***` before it is stored. `test-ai` returns `{ ok:false, reason, status?, detail? }`. `generate-review` (customer endpoint) never returns or logs `status` or `detail`; its responses and log lines stay exactly as today. The key is still never returned. |
| G2 | **Model listing via `test-ai`.** `test-ai` accepts `{ provider, action }` with `action` in `'test'` (default, current behaviour) or `'list_models'`. `list_models` is Super Admin only (same authentication as today), uses the saved key from `get_ai_provider_runtime`, 8 s timeout, and calls: Gemini `GET https://generativelanguage.googleapis.com/v1beta/models?pageSize=100` (header `x-goog-api-key`), keep entries whose `supportedGenerationMethods` includes `generateContent`, id = `name` without the `models/` prefix; Anthropic `GET https://api.anthropic.com/v1/models?limit=100` (headers `x-api-key`, `anthropic-version: 2023-06-01`), id = `data[].id`; OpenAI and custom `GET {base_url or https://api.openai.com/v1}/models` (Bearer), id = `data[].id` (same base-URL guard as today). Response `{ ok:true, models:[string] }` (unique, sorted, at most 200) or `{ ok:false, reason, status?, detail? }` with the same reason kinds as `test`. Redirects stay disabled. |
| G3 | **Admin UI.** In each provider card on `/admin/ai`: a "Load models" button (enabled only when a key is saved) calls `test-ai` with `action:'list_models'`. The Model input gets an HTML `datalist` of the returned ids, so the admin can pick one or still type any name. A short line shows "N models available" or the failure. Test and Load-models failures show: the existing reason text, then ` (HTTP {status}: {detail})` when `status` or `detail` is present. No new route and no database change. |
| G4 | **One retry for customers.** New `generateWithRetry(args)` in `providers.js` wraps `generate`: on a `ProviderError` of kind `unavailable` (HTTP 5xx) it waits 400 ms and tries once more; every other kind fails immediately. The whole operation stays inside the existing single 8 s deadline (one `AbortController` for both attempts). `generate-review` uses `generateWithRetry`; `test-ai` keeps plain `generate` so Test shows the real first response. |
| G5 | **Free-text model stays.** Saving a model that is not in the loaded list is allowed (no validation against the list), because providers add models and lists can lag. |
| G6 | **Safety.** Provider error text is shown only to a signed-in Super Admin inside Test and Load models; it is never stored, never sent by `generate-review`, and never logged. Log lines in all functions keep fixed event names only. |
| G7 | **Out of scope (later).** Automatic fallback to a second provider, caching model lists, showing model prices or limits, validating the model before saving, retry on quota (429) errors. |

## Status
- [x] 01 — Provider detail and redaction, list-models, one retry, admin UI, SPEC and acceptance evidence (node/mock checks only; deploy and real-provider checks NOT RUN)

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | none | Sonnet | `supabase/functions/_shared/providers.js`, `supabase/functions/test-ai/index.ts`, `supabase/functions/generate-review/index.ts`, `web/src/admin/AiSettingsPage.jsx`, `SPEC.md`, `docs/plans/08-ai-diagnostics-and-models/RESULT.md` |

One slice, no database change. After it, redeploy both functions: `npx supabase functions deploy test-ai` and `npx supabase functions deploy generate-review`.

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; no real API keys anywhere (obvious fakes only); `cd web && npm run build` must pass; no Deno, network or provider is available: verify the pure logic with `node` and a mocked `fetch` (scratchpad scripts only, nothing added to the repo) and report real-provider checks NOT RUN; append `## Result` to the slice file.

## Acceptance checklist
- [ ] With a deliberately wrong model name, Test shows the reason plus `(HTTP 404: …)` with Gemini's own message; with a wrong key it shows the 401/403 detail.
- [ ] No error detail, status or provider text ever appears in `generate-review` responses or logs (customer endpoint unchanged).
- [ ] The API key never appears in any returned `detail` (redaction verified with a mock that echoes the key).
- [ ] "Load models" on the Gemini card fills the Model suggestions with models that support `generateContent`; the admin can pick one or type another.
- [ ] Load models works for Claude and OpenAI-compatible providers (checked with real keys by the user).
- [ ] A provider 5xx on the first call and 200 on the second makes `generate-review` succeed; two 5xx fail with the usual friendly message; a 4xx is not retried.
- [ ] `SPEC.md` mentions model listing, the admin-only error detail and the single retry.
