# 09 — AI error log for the Super Admin

Master plan: none (`SPEC.md` gets a short update in slice 02) · Builds on and amends: [`../06-ai-review-generation/00-README.md`](../06-ai-review-generation/00-README.md) (A5, A11) and [`../08-ai-diagnostics-and-models/00-README.md`](../08-ai-diagnostics-and-models/00-README.md) (G1, G6: the customer endpoint may now store, never return, redacted error detail)

## Goal
- When "Write my review with AI" fails for a customer ("Couldn't generate right now"), the Super Admin can open `/admin/ai` and see why: which step failed, the provider, the model, the HTTP status and the provider's own message.
- Customers still see only the friendly generic message. Nothing sensitive reaches the browser.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| H1 | **Table.** New migration `supabase/migrations/20261123000001_ai_error_log.sql` (never edit earlier ones). `ai_error_log(id uuid primary key default gen_random_uuid(), created_at timestamptz not null default now(), stage text not null check (stage in ('context','runtime','not_configured','provider','empty')), provider text null, model text null, kind text null check (char_length(kind) <= 30), status int null, detail text null check (char_length(detail) <= 200))`, index `(created_at desc)`. RLS enabled, `revoke all` from anon and authenticated, no policies, no grants (access only through the RPCs below). It stores no prompt, no review text, no customer data, no key and no branch or keyword ids. |
| H2 | **Write RPC (service role only).** `log_ai_error(p_stage text, p_provider text, p_model text, p_kind text, p_status int, p_detail text) returns void`, security definer, `set search_path = public`, `revoke all from public, anon, authenticated`, `grant execute to service_role`. Invalid `p_stage` raises `22023`; `p_kind` is cut to 30 characters and `p_detail` to 200; then it deletes all but the newest 200 rows (so the table cannot grow without bound). |
| H3 | **Read RPC (Super Admin only).** `get_ai_errors(p_limit int default 20) returns jsonb`, security definer, `set search_path = public`, `revoke all from public`, `grant execute to authenticated`; `42501 'forbidden'` unless `current_app_role() = 'super_admin'`; limit clamped to 1–100; returns a JSON array of `{id, created_at, stage, provider, model, kind, status, detail}` newest first. Also `clear_ai_errors() returns void` (same role rule) deleting all rows. |
| H4 | **Edge Function.** `supabase/functions/generate-review/index.ts` calls `log_ai_error` (best effort: wrapped in try/catch, awaited with a 1 s timeout, never changes the HTTP response or status) on every failure path: `get_review_context` error other than `22023` → stage `context`; `get_ai_runtime` error → stage `runtime`; runtime null → stage `not_configured`; provider `ProviderError` → stage `provider` with `provider`, `model`, `kind`, `status` and the already-redacted `detail` from plan 08 G1; empty text → stage `empty`. `invalid_keywords` (22023) and `not_found` are caller errors and are not logged. Responses, status codes and `console` lines stay exactly as today (fixed event names only). The key, prompt and generated text are never passed to `log_ai_error`. |
| H5 | **Admin UI.** `/admin/ai` gets a "Recent AI errors" card below the provider cards: a table (time as local date and time, stage, provider and model, kind, HTTP status, detail as plain text), a Refresh button, a Clear button (ConfirmDialog, calls `clear_ai_errors`), and "No errors recorded." when empty. Data from `supabase.rpc('get_ai_errors', { p_limit: 20 })`. Stage labels: `context` "Loading branch", `runtime` "Loading AI settings", `not_configured` "AI not configured", `provider` "AI provider", `empty` "Empty reply". RPC error `forbidden` shows "Only a Super Admin can view this." |
| H6 | **Customer UI unchanged.** The button, the generic message and the template fallback stay as they are. |
| H7 | **Tests.** `supabase/tests/rls.sql`: no role can select or write `ai_error_log` directly; `log_ai_error` is not executable by anon or authenticated and works for the service role (switch with `set local role service_role`), rejects an invalid stage, truncates `kind` and `detail`, and keeps only the newest 200 rows (insert 205, expect 200); `get_ai_errors` and `clear_ai_errors` allowed for super admin and `42501` for business admin and anon; `get_ai_errors` returns newest first and respects the limit clamp. |
| H8 | **Out of scope (later).** Alerts or email on errors, error counts on the dashboard, logging customer-side validation errors, storing request or response bodies. |

## Status
- [x] 01 — Table, RPCs and tests (static review only; DB tests NOT RUN, user applies migration)
- [x] 02 — Edge Function logging, admin errors card, SPEC and acceptance evidence (browser/deploy checks NOT RUN)

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | 02 (contract fixed by H1–H3) | Sonnet | `supabase/migrations/20261123000001_ai_error_log.sql` (new), `supabase/tests/rls.sql` |
| 02 | none | 01 | Sonnet | `supabase/functions/generate-review/index.ts`, `web/src/admin/AiSettingsPage.jsx`, `web/src/styles.css` (appended `aie-` block), `SPEC.md`, `docs/plans/09-ai-error-log/RESULT.md` |

Disjoint files, so they run in parallel. Apply order for you: the migration first, then redeploy `generate-review`, then open `/admin/ai`. Acceptance is folded into slice 02.

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; no real keys anywhere; `cd web && npm run build` must pass for web slices; SQL and the Edge Function are statically reviewed (no database or Deno here: report those checks NOT RUN); append `## Result` to the slice file.

## Acceptance checklist
- [ ] After the migration, `rls.sql` prints `ALL RLS TESTS PASSED`; no role can read `ai_error_log` directly.
- [ ] Triggering a failed generation (for example a wrong model name) adds a row visible in "Recent AI errors" with stage `provider`, the provider, model, HTTP status and the provider's message, and the customer still sees only "Couldn't generate right now."
- [ ] The key never appears in any stored or displayed detail; no prompt, review text or customer data is stored.
- [ ] A Business Admin cannot call `get_ai_errors` or `clear_ai_errors`.
- [ ] Refresh and Clear work; the table keeps at most 200 rows.
- [x] A logging failure never changes the customer response (the function still returns its normal status and body).
- [x] `SPEC.md` describes the error log and who can see it.
