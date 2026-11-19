# 07/02 — Edge Function, admin page, customer message, SPEC and acceptance evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 07/01 (disjoint files)

## Decisions you need
R2 (function), R3 (admin page), R4 (customer message), R6 (safety note wording), R7 (docs) — run `grep -E '^\| (R2|R3|R4|R6|R7) ' 00-README.md`.

## Read first
- `supabase/functions/generate-review/index.ts`: the `log_ai_generation` rpc call, the `client_hash` computation (SHA-256 of `x-forwarded-for`), and the `429 rate_limited` response.
- `web/src/admin/AiSettingsPage.jsx`: the Daily limit state, input, hint, and the `set_ai_settings` call.
- `web/src/customer/FeedbackFormView.jsx`: the failure handling that checks `err?.context?.status === 429`.
- `SPEC.md`: lines mentioning rate limits, `daily_limit`, `ai_generation_log`, `log_ai_generation` (use `grep -n -i "daily\|rate limit\|ai_generation_log\|log_ai"`).
- `docs/plans/06-ai-review-generation/RESULT.md`: the acceptance row about the 7th request / daily limit and the Runbook section.

## Scope (files you own)
`supabase/functions/generate-review/index.ts`, `web/src/admin/AiSettingsPage.jsx`, `web/src/customer/FeedbackFormView.jsx`, `SPEC.md`, `docs/plans/06-ai-review-generation/RESULT.md`, `docs/plans/06-ai-review-generation/00-README.md` (one added line only), `docs/plans/07-remove-ai-limits/RESULT.md` (new).

## Tasks
1. **Function (R2).** Remove the `log_ai_generation` call, the `client_hash` computation and its helper code if unused, and the 429 response. Keep everything else and the other status codes. Make sure no unused variable or import remains.
2. **Admin page (R3, R6).** Remove the Daily limit input, hint and state; call `supabase.rpc('set_ai_settings', { p_active_provider, p_is_enabled })`. Under the "Enable AI reviews" checkbox add the hint "Set a spending or quota limit in your AI provider's console." (plain text, no link).
3. **Customer (R4).** Remove the 429 branch; all failures show "Couldn't generate right now. You can edit the text below."
4. **Docs (R7).** `SPEC.md`: delete every statement about AI rate limits, daily limit and the `ai_generation_log` table, and add one sentence: AI calls are not limited by the app, so a quota should be set at the provider. Plan 06 `RESULT.md`: add "Amended by plan 07: AI limits removed." at the top, rewrite the acceptance row about the 7th request and the daily limit as "No AI limits (plan 07)" with status "not verified (needs browser/provider key)" and manual step "generate more than 6 reviews in 10 minutes from one phone; none is refused", remove limit items from the runbook, and drop the "shared bucket for null client hash" known gap. Plan 06 `00-README.md`: add the one line "Amended by plan 07: AI limits removed." under the title.
5. **RESULT.md (this plan).** One row per acceptance checkbox in `00-README.md`: verified or "not verified (needs DB/browser/deploy)" with evidence and exact manual steps (apply the migration, redeploy `npx supabase functions deploy generate-review`, then the UI checks). Only build, grep and static facts may be marked verified. Do not tick Status boxes for slice 01.

## Done when
- `cd web && npm run build` passes.
- `grep -rn "log_ai_generation\|client_hash\|rate_limited\|daily_limit\|dailyLimit" supabase/functions web/src SPEC.md` finds nothing.
- `grep -n -i "429" web/src/customer/FeedbackFormView.jsx` finds nothing.
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
Changed: `supabase/functions/generate-review/index.ts` (removed `clientHash`, `log_ai_generation` call, 429), `web/src/admin/AiSettingsPage.jsx` (no daily limit; quota hint; two-arg RPC), `web/src/customer/FeedbackFormView.jsx` (single failure message), `SPEC.md`, plan 06 `RESULT.md` and `00-README.md`, new `docs/plans/07-remove-ai-limits/RESULT.md`.
Checks: `cd web && npm run build` PASS; forbidden-names grep over `supabase/functions web/src SPEC.md` empty PASS; `429` grep in FeedbackFormView empty PASS. Deno/DB/browser NOT RUN. Slice 01 status boxes not ticked.
