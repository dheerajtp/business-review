# 14 — Show provider billing errors as billing errors

Master plan: none · Builds on and amends: [`../08-ai-diagnostics-and-models/00-README.md`](../08-ai-diagnostics-and-models/00-README.md) (G1 error kinds) and [`../11-ai-resilience/00-README.md`](../11-ai-resilience/00-README.md) (fallback rules) · Follows: [`../13-ai-first-key-setup/00-README.md`](../13-ai-first-key-setup/00-README.md)

## Goal
- When a provider refuses because the account has no credit (Anthropic returns HTTP 400 "Your credit balance is too low"), the Test button says so instead of "The model name or base URL looks wrong."
- The Super Admin knows to add credit, or to switch provider, instead of hunting for a model typo.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| U1 | **Cause.** `supabase/functions/_shared/providers.js` `statusKind` maps every HTTP 400 and 404 to kind `model`; Anthropic's billing refusal is a 400 and the key and model are fine. This is the account, not the code: the user's Anthropic account needs credit (Plans & Billing in the Anthropic console). |
| U2 | **Reclassify.** In `request()` (the `!res.ok` branch), when `res.status` is 400, 402 or 403 and the redacted `detail` matches `/credit balance|insufficient (credit|funds|quota)|billing|payment required/i`, throw kind `quota` instead of the `statusKind` result. 402 is `quota` even without a match. All other statuses keep `statusKind`. `status` and redacted `detail` stay on the error as today. |
| U3 | **Message.** In `web/src/admin/AiSettingsPage.jsx` `TEST_REASONS.quota` becomes "The provider says this account has no credit or has hit its quota or rate limit. Add credit or check limits in the provider's console, or switch provider." Failure text still appends `HTTP status: detail`. |
| U4 | **Fallback rule unchanged.** `generateResilient` falls back only on `unavailable` and `model`; with U2 a billing refusal is `quota`, so it no longer wastes a fallback attempt and the customer sees the existing generic failure with its ref code (plans 09, 10 unchanged). |
| U5 | **Tests.** Node mock check in the scratchpad: mocked fetch returns 400 with a body containing "credit balance is too low" → kind `quota`, status 400, detail redacted; plain 400 "model not found" → still `model`; 402 with empty body → `quota`; 429 → `quota`; 500 → `unavailable`; the key never appears in the error. `cd web && npm run build` passes. Deploy and browser NOT RUN. |
| U6 | **Out of scope (later).** Auto-switching to another provider on billing errors, enabling AI without a passing Test, seeding default model names. |

## Status
- [x] 01 — Reclassify billing refusals and fix the Test message (build and node mock check PASS; deploy and browser NOT RUN)

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | none | Haiku | `supabase/functions/_shared/providers.js`, `web/src/admin/AiSettingsPage.jsx` (`TEST_REASONS.quota` line only), `docs/plans/14-ai-billing-errors/RESULT.md` |

Apply order for you: `npx supabase functions deploy test-ai` and `npx supabase functions deploy` for whichever function generates customer reviews (it imports the same `_shared/providers.js`).

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; no real keys anywhere; `cd web && npm run build` must pass; Edge Function code is statically reviewed plus the node mock check; append `## Result` to the slice file.

## Acceptance checklist
- [ ] Testing Claude on an account with no credit shows the new credit/quota message with "HTTP 400: Your credit balance is too low…".
- [ ] A wrong model name still shows "The model name or base URL looks wrong."
- [ ] Once the account has credit (or another provider passes Test), Test succeeds and Enable AI reviews becomes tickable.
