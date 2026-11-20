# 13/01 — Load models with an unsaved key

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: none

## Decisions you need
S1–S6 — run `grep -E '^\| S[1-6] ' 00-README.md`.

## Read first
- `supabase/functions/test-ai/index.ts` lines 60–112 (auth, body validation, `get_ai_provider_runtime`, the early `no_key` return at `if (!runtime)`, the `list_models` branch) and `syncModels` (line ~41).
- `supabase/functions/_shared/urlGuard.js` (exported base-URL check; reuse it, do not re-implement).
- `supabase/functions/_shared/providers.js`: `listModels` signature and how it treats a missing `base_url` per provider.
- `web/src/admin/AiSettingsPage.jsx`: `ProviderCard` (lines 69–225): `loadModels`, `hasKey`, the three action buttons at ~218–221, the model hint and `<Field label="API key">`.

## Scope (files you own)
- `supabase/functions/test-ai/index.ts`
- `web/src/admin/AiSettingsPage.jsx`
- `docs/plans/13-ai-first-key-setup/RESULT.md`

## Tasks
1. **Function: accept an unsaved key (S2, S3).** In step 2 read `body.api_key` and `body.base_url`. Only for `action === "list_models"`: `api_key` counts as supplied when it is a non-empty string. If supplied and not 8–400 chars or contains whitespace, return `fail({kind:"auth"})`-shaped `{ ok:false, reason:"auth" }` before any network call. The `test` action ignores both fields.
2. **Function: runtime fallback.** The early `if (!runtime) return no_key` must not fire for `list_models` with a supplied key. Build an effective runtime: `provider`, `api_key` = typed key (else `runtime.api_key`), `base_url` = for `custom` (and `openai`) the typed `base_url` if given and it passes the urlGuard check (invalid → `{ ok:false, reason:"unknown" }`... use the same reason the saved-URL failure path already returns, if none exists use `"unknown"`), else `runtime?.base_url`; Gemini and Claude never take a typed base URL. When there is no saved row and no typed key keep today's `no_key` response.
3. **Function: no leakage.** The typed key must not appear in any `console.*` call, response, `fail` detail or the error-log RPC payload. Confirm `listModels` error `detail` cannot echo the key (provider adapters redact; if you see a path that could, strip the key string from `detail` before returning).
4. **UI: Load models enabled (S4, S5).** In `loadModels` send `api_key: key || undefined` and, when `meta.url`, `base_url: baseUrl.trim() || undefined` in the invoke body. Button disabled rule: `busy || !(hasKey || key) || (meta.url === 'required' && !hasKey && !baseUrl.trim())`. Test keeps `busy || !hasKey`. Add `title` attributes: Load models disabled → "Paste an API key first" (or "Enter the Base URL first" for a required URL); Test disabled → "Save an API key first"; Save disabled and not busy → "Pick a model first".
5. **UI: hint (S4).** Show `<p className="hint">Paste your API key, then click Load models.</p>` instead of the existing "Click Load models to fill this list…" line when `!hasKey && !key` and the provider has no models; keep the existing line otherwise. After Load models succeeds, leave the typed key in the box so Save stores key and model together (Save already sends `key`).
6. **Node mock check (S6).** In the scratchpad directory (not the repo): mock Supabase client and `listModels`; assert: typed key is passed to the adapter instead of the vault key; response JSON and captured `console` output never contain the key; `"short"` and `"abc defghij"` give `reason:"auth"` with no adapter call; no saved row + typed key proceeds and calls `sync_ai_models`; no saved row + no key returns `no_key`; `test` action ignores `api_key`. Paste the assertion output summary into `RESULT.md`.

## Done when
- `cd web && npm run build` passes; the node mock check passes.
- On a card with no key, pasting a key enables Load models (read by inspection of the JSX conditions, browser NOT RUN); Gemini card logic with a saved key is unchanged.
- No new files outside Scope. Append `## Result` to this file, listing deploy (`npx supabase functions deploy test-ai`) and browser checks as NOT RUN.

## Result
Changed: `supabase/functions/test-ai/index.ts` (typed `api_key`/`base_url` for `list_models` only; shape check -> `auth`; no_key only when no saved row and no typed key; invalid typed URL -> `unknown`; adapter already redacts the key), `web/src/admin/AiSettingsPage.jsx` (loadModels sends key/base_url, new disable rule, titles, hint). `RESULT.md` not created (this section serves).
- `cd web && npm run build` -> PASS.
- Node mock check (scratchpad, handler transpiled by sed, mocked Supabase/listModels) -> ALL PASS: typed key reaches adapter not vault key; key absent from response and console; "short" and "abc defghij" -> auth with no adapter call; no row + key syncs; no row + no key -> no_key; `test` ignores api_key; invalid base_url -> unknown.
- NOT RUN: `npx supabase functions deploy test-ai`, browser checks, Deno type-check.
