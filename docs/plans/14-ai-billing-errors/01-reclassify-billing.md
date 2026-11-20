# 14/01 — Reclassify billing refusals and fix the Test message

Plan folder: [`00-README.md`](00-README.md) · Model: Haiku · Prerequisites: none · Parallel with: none

## Decisions you need
U1–U5 — run `grep -E '^\| U[1-5] ' 00-README.md`.

## Read first
- `supabase/functions/_shared/providers.js` lines 1–60: `ProviderError`, `statusKind`, `errorDetail`, `request()` (the `!res.ok` branch).
- `web/src/admin/AiSettingsPage.jsx` lines 18–27: `TEST_REASONS`.

## Scope (files you own)
- `supabase/functions/_shared/providers.js`
- `web/src/admin/AiSettingsPage.jsx` (the `quota:` line in `TEST_REASONS` only)
- `docs/plans/14-ai-billing-errors/RESULT.md`

## Tasks
1. **Reclassify (U2).** In `request()`, after `const detail = await errorDetail(res, key);`, compute `const billing = res.status === 402 || ([400, 403].includes(res.status) && /credit balance|insufficient (credit|funds|quota)|billing|payment required/i.test(detail ?? ""));` and throw `new ProviderError(billing ? "quota" : statusKind(res.status), { status: res.status, detail })`. Keep `status` and the redacted `detail`.
2. **Message (U3).** Replace the `quota:` string in `TEST_REASONS` with: `The provider says this account has no credit or has hit its quota or rate limit. Add credit or check limits in the provider's console, or switch provider.`
3. **Node mock check (U5).** In the scratchpad directory (not the repo), mock `fetch` and call `request` or the exported adapter: 400 + "credit balance is too low" → `quota`, status 400; 400 + "model not found" → `model`; 402 empty body → `quota`; 429 → `quota`; 500 → `unavailable`; the key never appears in the error's message or detail. Put the output summary in `RESULT.md`.

## Done when
- `cd web && npm run build` passes; the node mock check passes.
- No files changed outside Scope. Append `## Result` to this file; list deploy and browser checks as NOT RUN.

## Result
- Changed: `supabase/functions/_shared/providers.js` (billing reclassification in `request()`), `web/src/admin/AiSettingsPage.jsx` (`TEST_REASONS.quota` line only), `docs/plans/14-ai-billing-errors/RESULT.md` (new).
- `cd web && npm run build` → PASS.
- Node mock check (scratchpad copy, 8 cases incl. key-leak check) → ALL PASS. Details in RESULT.md.
- NOT RUN: edge function deploy, browser check of the Test message.
