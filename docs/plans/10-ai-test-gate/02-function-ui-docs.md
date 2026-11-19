# 10/02 — Function and admin UI changes, SPEC and acceptance evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 10/01 (disjoint files)

## Decisions you need
T7 (test-ai records results), T8 (self-switch-off), T9 (admin UI), T11 (out of scope) — run `grep -E '^\| (T7|T8|T9|T11) ' 00-README.md`. RPC contracts you call (T2, T4, T6, being written in 10/01): `record_ai_test(p_provider text, p_ok boolean)` via service role; `set_ai_settings` may now fail with message `provider not tested`; `get_ai_settings().providers[]` gains `last_test_ok` (boolean) and `last_tested_at` (timestamp or null).

## Read first
- `supabase/functions/test-ai/index.ts`: the `action === 'test'` path and where it returns `{ok:true,...}` / `{ok:false,...}`; the service-role client `admin`.
- `supabase/functions/generate-review/index.ts`: the provider `catch` that already calls `logError(...)` (plan 09) and the `logError` helper's best-effort/timeout style to copy.
- `web/src/admin/AiSettingsPage.jsx`: provider cards (status pill `Key saved`/`No key`), the global Settings card (active provider select, Enable checkbox, `set_ai_settings` call), `rpcError` mapping, the `test()` handler and how the page reloads (`reload`/`useAsync`).

## Scope (files you own)
`supabase/functions/test-ai/index.ts`, `supabase/functions/generate-review/index.ts`, `web/src/admin/AiSettingsPage.jsx`, an appended `aig-` block in `web/src/styles.css`, `SPEC.md`, `docs/plans/10-ai-test-gate/RESULT.md` (new).

## Tasks
1. **test-ai (T7).** After a completed `test` run, call `admin.rpc("record_ai_test", { p_provider: provider, p_ok: <true when ok, else false> })` inside try/catch (best effort, 1 s race like `logError`), for success, for provider failures and for an empty reply. Do not record when the reason is `no_key` or on `list_models`. The HTTP response, JSON shape and status codes stay exactly as they are.
2. **generate-review (T8).** In the provider `catch`, after the existing `logError`, if `e?.kind` is `"auth"` or `"model"` call `record_ai_test(runtime.provider, false)` with the same best-effort pattern. No other kind triggers it. The response (`502 ai_failed`), log lines and everything else stay unchanged.
3. **Admin UI (T9).** In each provider card show a second pill next to Key saved/No key: "Tested OK · {local time}" when `last_test_ok`, else "Not tested" (only when a key is saved). In the Settings card disable the Enable checkbox unless the selected active provider has `has_key && last_test_ok`, with the hint "Run Test successfully on the active provider first."; the active-provider select lists only providers with a key. Map the `set_ai_settings` error message `provider not tested` to "Run Test successfully first." After Test completes (success or failure) reload the settings so pills and the checkbox update. Save of a changed provider already reloads; the pill then shows "Not tested" from the server data. Append `aig-` CSS only.
4. **SPEC.md.** In the AI section add: AI can be enabled only after a successful Test of the active provider; changing model, key or URL requires a new Test; the customer button shows only while the provider is tested; a bad key or wrong model seen during customer generation switches it off until re-tested. Add `last_test_ok` and `last_tested_at` to the `ai_providers` description.
5. **RESULT.md.** One row per acceptance checkbox in `00-README.md`: verified or "not verified (needs DB/deploy/provider key)" with evidence and exact manual steps (apply the migration, redeploy `npx supabase functions deploy test-ai` and `npx supabase functions deploy generate-review --no-verify-jwt`, then the `/admin/ai` and customer-page checks). Row 1 and DB rows depend on 10/01 running in parallel: mark not verified and reference its Result. Only build, grep and static facts may be marked verified. Do not tick Status boxes for 10/01.

## Done when
- `cd web && npm run build` passes.
- `grep -n "record_ai_test" supabase/functions/test-ai/index.ts supabase/functions/generate-review/index.ts` shows the calls; in `generate-review` it appears only inside the `auth`/`model` condition.
- HTTP responses and status codes of both functions are unchanged (state how you checked by reading the diff).
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
STATUS: DONE. Changed: `supabase/functions/test-ai/index.ts` (`recordTest`, called for success, provider failure and empty reply on `action === "test"` only), `supabase/functions/generate-review/index.ts` (`recordFailedTest` under `auth`/`model`), `web/src/admin/AiSettingsPage.jsx` (second pill, gated checkbox and hint, `provider not tested` mapping, reload after Test, GlobalSettings key includes `last_test_ok`), `web/src/styles.css` (`aig-` block), `SPEC.md`, `RESULT.md`.
Checks: `cd web && npm run build` PASS; grep for `record_ai_test` PASS; Deno/DB/browser NOT RUN.
Notes: ProviderCard key deliberately excludes `last_test_ok` so the Test message survives the reload. The active-provider select already listed only keyed providers (unchanged). Slice 01 contract (`record_ai_test`, `last_test_ok`, `last_tested_at`) assumed, not verified.
