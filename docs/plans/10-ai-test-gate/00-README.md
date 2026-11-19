# 10 — Only show the AI button when the AI setup has passed a test

Master plan: none (`SPEC.md` gets a short update in slice 02) · Builds on and amends: [`../06-ai-review-generation/00-README.md`](../06-ai-review-generation/00-README.md) (A2, A4) and [`../07-remove-ai-limits/00-README.md`](../07-remove-ai-limits/00-README.md) (R1: `set_ai_settings(text, boolean)`)

## Goal
- A customer never sees "Write my review with AI" unless the saved provider, model and key have just passed a real test.
- A provider that stops working because of its configuration (bad key, wrong model) switches the button off by itself until the Super Admin tests it again.
- Enabling AI on `/admin/ai` is only possible after a successful Test, so "enabled but broken" can no longer happen.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| T1 | **Columns.** New migration `supabase/migrations/20261124000001_ai_test_gate.sql` (never edit earlier ones): `alter table public.ai_providers add column last_test_ok boolean not null default false, add column last_tested_at timestamptz null`. Existing rows start as not tested. |
| T2 | **record_ai_test.** `record_ai_test(p_provider text, p_ok boolean) returns void`, security definer, `set search_path = public`, `revoke all from public, anon, authenticated`, `grant execute to service_role`. Invalid provider raises `22023`; sets `last_test_ok = coalesce(p_ok, false)` and `last_tested_at = now()` for that provider row (no row = no-op). |
| T3 | **Reset on change.** `set_ai_provider` (plan 06 A2, signature unchanged) sets `last_test_ok = false, last_tested_at = null` whenever the model, the base URL or the key actually changes (a null key keeps the old key and, with unchanged model and base URL, leaves the test result alone). `clear_ai_provider_key` also resets them. |
| T4 | **Enable gate.** `set_ai_settings(p_active_provider text, p_is_enabled boolean)` (signature unchanged): enabling now also requires the active provider row to have `last_test_ok = true`, else `22023 'provider not tested'`; the existing `provider has no key` check stays first. Switching the active provider while enabled follows the same rule (the new provider must be tested), otherwise the call is rejected with the same error and nothing changes. |
| T5 | **Form flag.** `get_feedback_form` keeps every field and signature; `ai_enabled` = `is_enabled` and the active provider has a key and `last_test_ok` (drop and recreate with the same grants, copy the current body from the latest migration that defines it, `20261121000001_ai_review.sql`). |
| T6 | **Settings read.** `get_ai_settings()` adds `last_test_ok` and `last_tested_at` to each entry of `providers` (drop and recreate, same grant; never return the key or `secret_id`). |
| T7 | **test-ai records results.** After every `action: 'test'` run, `supabase/functions/test-ai/index.ts` calls `record_ai_test(provider, ok)` through the service-role client, best effort (try/catch, never changes the response). `list_models` does not record. |
| T8 | **Self-switch-off.** `generate-review` calls `record_ai_test(runtime.provider, false)` (best effort) when the provider call fails with `ProviderError.kind` equal to `auth` or `model` (a configuration problem). Kinds `unavailable`, `quota`, `timeout`, `network`, `unknown` and an empty reply do **not** switch it off. Responses and status codes are unchanged. |
| T9 | **Admin UI.** Each provider card shows a status pill: "Tested OK" with the local time, or "Not tested". The "Enable AI reviews" checkbox is disabled, with the hint "Run Test successfully on the active provider first.", unless the active provider is `last_test_ok`; the active-provider select only offers providers with a key. Error `provider not tested` maps to "Run Test successfully first." After Test, the page reloads settings so the pill and the checkbox update. Saving a changed model, key or base URL shows the pill as "Not tested" again. |
| T10 | **Tests.** `supabase/tests/rls.sql`: new columns default to false; `record_ai_test` not executable by anon or authenticated, works as `service_role`, rejects an invalid provider; `set_ai_provider` resets the flag on a changed model, base URL or key and keeps it for a no-op save; `clear_ai_provider_key` resets it; `set_ai_settings(..., true)` fails with `provider not tested` until `record_ai_test(..., true)` ran, then succeeds; switching the active provider to an untested one while enabled fails; `get_feedback_form.ai_enabled` is false until enabled, keyed and tested, and false again after a recorded failure; `get_ai_settings()` shows the two fields and still contains no key. Existing AI assertions that enable AI must record a successful test first. |
| T11 | **Out of scope (later).** Scheduled re-tests, alerts when the button switches itself off, switching off on quota or outage, per-model tests. |

## Status
- [x] 01 — Columns, RPCs, gates and tests (static review only; DB tests NOT RUN, user applies migration)
- [x] 02 — Function and admin UI changes, SPEC and acceptance evidence (gated while 01 in flight; deploy/browser checks NOT RUN)

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | 02 (contract fixed by T1–T6) | Sonnet | `supabase/migrations/20261124000001_ai_test_gate.sql` (new), `supabase/tests/rls.sql` |
| 02 | none | 01 | Sonnet | `supabase/functions/test-ai/index.ts`, `supabase/functions/generate-review/index.ts`, `web/src/admin/AiSettingsPage.jsx`, `web/src/styles.css` (appended `aig-` block), `SPEC.md`, `docs/plans/10-ai-test-gate/RESULT.md` |

Disjoint files, so they run in parallel. Apply order for you: the migration first, then redeploy both functions, then use `/admin/ai`: Test, then enable.

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; no real keys anywhere; `cd web && npm run build` must pass for web slices; SQL and Edge Functions are statically reviewed (no database or Deno here: report those checks NOT RUN); append `## Result` to the slice file.

## Acceptance checklist
- [ ] After the migration, `rls.sql` prints `ALL RLS TESTS PASSED`.
- [ ] On `/admin/ai` the Enable checkbox is disabled until Test succeeds for the active provider; after a successful Test it can be enabled.
- [ ] Changing the model, base URL or key puts the provider back to "Not tested" and the customer button disappears until Test passes again.
- [ ] With a wrong model or key, Test fails, AI cannot be enabled, and the review page shows no AI button.
- [ ] If an enabled provider starts failing with a bad key or model, the first failed customer click switches the button off for later visitors; an outage or quota error does not.
- [x] `SPEC.md` describes the test gate.
