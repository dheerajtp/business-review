# 07 — Remove the AI review limits

Master plan: none (`SPEC.md` is updated in slice 02) · Builds on and amends: [`../06-ai-review-generation/00-README.md`](../06-ai-review-generation/00-README.md) (removes A1 `daily_limit` and `ai_generation_log`, A2 `p_daily_limit`, A3 `log_ai_generation` and `daily_limit`, A5 `429 rate_limited`, A9 daily-limit field, A11 rate limits)

## Goal
- AI review generation is never blocked by volume: no daily cap and no per-customer burst limit.
- The "Daily limit" field disappears from `/admin/ai`.
- Review submissions (the existing 30 per 10 minutes per branch per client flood control) are **not** touched.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| R1 | **Migration.** New `supabase/migrations/20261122000001_remove_ai_limits.sql` (never edit earlier ones), in this order: (1) `drop function public.log_ai_generation(uuid, text)`; (2) `drop table public.ai_generation_log`; (3) drop the old `set_ai_settings(text, boolean, int)` and recreate it as `set_ai_settings(p_active_provider text, p_is_enabled boolean) returns void` with the same rules minus the limit (provider must be valid or null; enabling requires the active provider to have a saved key, else `22023 'provider has no key'`; `42501 'forbidden'` unless super admin; security definer, `set search_path = public`, `revoke all from public`, `grant execute to authenticated`); (4) `alter table public.ai_settings drop column daily_limit`; (5) recreate `get_ai_settings()` without `daily_limit` in its output, and `get_ai_runtime()` / `get_ai_provider_runtime(text)` without `daily_limit` in theirs (same grants as today: authenticated for `get_ai_settings`, service_role only for the runtime ones). Each drop uses the exact current signature; read plan 06's migration `20261121000001_ai_review.sql` for the bodies to copy. |
| R2 | **Edge Function.** `supabase/functions/generate-review/index.ts`: remove the `log_ai_generation` call, the `client_hash` computation and the `429 rate_limited` response. Everything else stays (method check, body ≤ 4 KB, input validation, `get_review_context`, `get_ai_runtime`, 8 s timeout, sanitize, status codes `413/400/404/503/502/500/405`). If `get_ai_runtime` still returns an unexpected `daily_limit` key nothing reads it. |
| R3 | **Admin page.** `web/src/admin/AiSettingsPage.jsx`: remove the Daily limit input, its hint and state; `set_ai_settings` is called with `{ p_active_provider, p_is_enabled }` only. |
| R4 | **Customer UI.** `web/src/customer/FeedbackFormView.jsx`: remove the special 429 message ("Please try again in a few minutes."); every failure shows "Couldn't generate right now. You can edit the text below." |
| R5 | **Tests.** `supabase/tests/rls.sql`: delete the `log_ai_generation` limit tests and daily-limit assertions; change every `set_ai_settings` call to two arguments; assert `get_ai_settings()::text` and the runtime RPC output contain no `daily_limit`; assert `to_regclass('public.ai_generation_log') is null` and that `public.log_ai_generation` does not exist; keep all other AI assertions (no direct table reads, super-admin-only RPCs, key never in output, enable needs a key, `ai_enabled` flag, URL guard, `get_review_context`). |
| R6 | **Safety note.** With no app-side limit, cost control moves to the provider: the runbook and the `/admin/ai` page text say "Set a spending or quota limit in your AI provider's console." Remaining guards stay: request body ≤ 4 KB, rating 1–5, ≤ 10 keyword ids checked against the branch, output capped at 300 tokens and 600 characters, 8 s timeout. |
| R7 | **Docs.** `SPEC.md` loses every statement about AI rate limits or a daily limit and gains one sentence on R6; `docs/plans/06-ai-review-generation/RESULT.md` gets a short "Amended by plan 07" note and its acceptance row about the 7th request and daily limit is rewritten as "no AI limits"; plan 06's README gets one line "Amended by plan 07: AI limits removed." |
| R8 | **Out of scope (later).** Replacing the limits with other protections (CAPTCHA, signed-in customers, per-company quotas, usage dashboards); changing the review submission flood control (`submit_feedback`, 30 per 10 minutes). |

## Status
- [x] 01 — Migration and tests (static review only; DB tests NOT RUN, user applies migration)
- [x] 02 — Edge Function, admin page, customer message, SPEC and acceptance evidence (browser/deploy checks NOT RUN)

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | 02 | Sonnet | `supabase/migrations/20261122000001_remove_ai_limits.sql` (new), `supabase/tests/rls.sql` |
| 02 | none | 01 | Sonnet | `supabase/functions/generate-review/index.ts`, `web/src/admin/AiSettingsPage.jsx`, `web/src/customer/FeedbackFormView.jsx`, `SPEC.md`, `docs/plans/06-ai-review-generation/RESULT.md`, `docs/plans/06-ai-review-generation/00-README.md` (one added line), `docs/plans/07-remove-ai-limits/RESULT.md` |

Disjoint files, so they run in parallel. Apply order for you: the migration (slice 01) and the redeploy of `generate-review` (slice 02) should go together; the new function works against either schema, but the new page calls `set_ai_settings` with two arguments, so apply the migration **before** using the updated admin page. Acceptance is folded into slice 02.

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; no real API keys anywhere; `cd web && npm run build` must pass for web slices; SQL and Edge Function code are statically reviewed (no database or Deno here: report those checks NOT RUN); append `## Result` to the slice file.

## Acceptance checklist
- [ ] After the migration, `ai_settings` has no `daily_limit`, `ai_generation_log` and `log_ai_generation` no longer exist, `set_ai_settings` takes two arguments, and `rls.sql` prints `ALL RLS TESTS PASSED`.
- [ ] `/admin/ai` has no Daily limit field; saving the active provider and the enable toggle works.
- [ ] Generating many AI reviews in a row from one client is never refused by the app (no 429 from `generate-review`).
- [ ] A provider failure still leaves the template text with the friendly message.
- [ ] Review submissions are still limited as before (30 per 10 minutes per branch per client).
- [x] `SPEC.md` and plan 06's `RESULT.md` no longer mention AI limits and carry the "set a quota in your provider" note.
