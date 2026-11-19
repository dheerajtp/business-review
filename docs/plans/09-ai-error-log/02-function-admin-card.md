# 09/02 — Edge Function logging, admin errors card, SPEC and acceptance evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 09/01 (disjoint files)

## Decisions you need
H4 (what is logged and where), H5 (admin card), H6 (customer unchanged), H8 (out of scope) — run `grep -E '^\| (H4|H5|H6|H8) ' 00-README.md`. RPC contracts you call (from H2/H3, being written in 09/01): `log_ai_error(p_stage, p_provider, p_model, p_kind, p_status, p_detail)` via service role; `get_ai_errors(p_limit)` returning a JSON array; `clear_ai_errors()`.

## Read first
- `supabase/functions/generate-review/index.ts`: every failure path (context error, runtime error, `!runtime`, the provider `catch`, the empty-review branch) and the final `json(...)` returns.
- `supabase/functions/_shared/providers.js`: `ProviderError` fields `kind`, `status`, `detail` (already redacted, plan 08).
- `web/src/admin/AiSettingsPage.jsx`: page structure, `useAsync`/`must` usage, `ConfirmDialog` usage for Remove key, `rpcError` mapping, the `ai-` CSS classes.
- `web/src/ui/ConfirmDialog.jsx`, `web/src/lib/format.js` (date formatting helpers).

## Scope (files you own)
`supabase/functions/generate-review/index.ts`, `web/src/admin/AiSettingsPage.jsx`, an appended `aie-` block in `web/src/styles.css`, `SPEC.md`, `docs/plans/09-ai-error-log/RESULT.md` (new).

## Tasks
1. **Best-effort logger (H4).** In `generate-review`, add a helper `logError(admin, fields)` that calls `admin.rpc("log_ai_error", { p_stage, p_provider, p_model, p_kind, p_status, p_detail })` inside try/catch, raced against a 1 s timeout, and never throws or changes the response. Fields not available are `null`. Call it on: `get_review_context` error other than `22023` (stage `context`, kind = error code if any), `get_ai_runtime` error (`runtime`), `!runtime` (`not_configured`), provider catch (`provider`, with `runtime.provider`, `runtime.model`, `e.kind`, `e.status ?? null`, `e.detail ?? null`), empty review (`empty`, with provider and model). Do not log `invalid_keywords`, `not_found`, `invalid_input`, `too_large`. Never pass the key, prompt, review text, slug, branch or keyword ids. Keep the existing `console` lines and every response body and status unchanged.
2. **Admin card (H5).** In `AiSettingsPage.jsx` add a "Recent AI errors" card below the provider cards: load with `supabase.rpc('get_ai_errors', { p_limit: 20 })`; table columns Time (local `toLocaleString`), Step (stage labels from H5), Provider / model, Kind, HTTP, Detail; render everything as plain text. Refresh button reloads; Clear button opens `ConfirmDialog` then `clear_ai_errors` and reloads; empty state "No errors recorded."; error `forbidden` shows "Only a Super Admin can view this."; other errors via the page's existing error helper. Wrap the table in a horizontally scrollable container for narrow screens. Append `aie-` CSS only.
3. **Customer UI.** Do not touch `web/src/customer/**` (H6).
4. **SPEC.md.** In the AI section add: failed generations are recorded (step, provider, model, status, redacted provider message, at most 200 rows, no customer data) and visible only to the Super Admin on `/admin/ai`; add `ai_error_log` to the data model list.
5. **RESULT.md.** One row per acceptance checkbox in `00-README.md`: verified or "not verified (needs DB/deploy/provider key)" with evidence and exact manual steps (apply the migration, redeploy `npx supabase functions deploy generate-review`, set a wrong model name, click the customer button, read the card). Row 1 and DB rows depend on 09/01 running in parallel: mark not verified and reference its Result. Only build, grep and static facts may be marked verified. Do not tick Status boxes for 09/01.

## Done when
- `cd web && npm run build` passes.
- `grep -n "log_ai_error" supabase/functions/generate-review/index.ts` shows the helper and the five call sites; `grep -n "p_slug\|keyword_ids\|prompt\|review" ` inside the `logError` calls shows none of those values passed.
- The function's HTTP responses and status codes are unchanged (state how you checked by reading the diff).
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
Changed: `supabase/functions/generate-review/index.ts` (best-effort `logError` helper, 1 s race, 5 call sites: context non-22023, runtime error, `!runtime`, provider catch, empty review; responses and console lines unchanged), `web/src/admin/AiSettingsPage.jsx` (`ErrorLog` card below the provider grid; Refresh, Clear with ConfirmDialog, empty state, `forbidden` message, plain-text cells), `web/src/styles.css` (appended `aie-` block), `SPEC.md` (data model entry, AI error log bullet), `docs/plans/09-ai-error-log/RESULT.md` (new).

Checks:
- `cd web && npm run build` PASS.
- `grep -n "log_ai_error\|logError" index.ts` shows helper plus five call sites; no call passes key, prompt, text, slug or keyword ids.
- Responses unchanged: checked by reading `git diff` (only added awaited `logError` lines; the `!runtime` branch became a block with the same 503 return).
- Deno, DB, browser: NOT RUN.

Note: the context-error `kind` is the Postgres error code (may be null); Clear is disabled when there are no rows.
