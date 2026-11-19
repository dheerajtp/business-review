# 12/02 — Function sync, admin dropdowns, SPEC and acceptance evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 12/01 (disjoint files)

## Decisions you need
L4 (list_models stores the list), L5 (dropdown UI), L6 (no DB coupling), L8 (node check), L9 (out of scope) — run `grep -E '^\| (L4|L5|L6|L8|L9) ' 00-README.md`. RPC contracts you call (L2/L3, being written in 12/01): `list_ai_models(p_provider)` returns a JSON array of `{provider, model_id, label, is_available, source}`; `add_ai_model(p_provider, p_model_id, p_label)`; `remove_ai_model(p_provider, p_model_id)`; service-role `sync_ai_models(p_provider, p_models text[])` returns int. Error messages: `invalid model id`, `synced models cannot be removed`, `model in use`, `forbidden`.

## Read first
- `supabase/functions/test-ai/index.ts`: the `action === "list_models"` branch (calls `listModels`, returns `{ ok:true, models }`), the service-role `admin` client, `recordTest`-style best-effort helpers.
- `web/src/admin/AiSettingsPage.jsx`: `ProviderCard` (Model input + `<datalist>`, Fallback model input, `models` state, Load models handler, Save handler), `rpcError`, page data loading (`get_ai_settings`), `TEST_REASONS`.
- `web/src/ui/Field.jsx` and an existing `<select className="select">` in `web/src/admin/CompanyForm.jsx` for markup/classes.

## Scope (files you own)
`supabase/functions/test-ai/index.ts`, `web/src/admin/AiSettingsPage.jsx`, an appended `aim-` block in `web/src/styles.css`, `SPEC.md`, `docs/plans/12-ai-models-table/RESULT.md` (new).

## Tasks
1. **Sync in test-ai (L4).** In `list_models`, after `listModels` returns, call `admin.rpc("sync_ai_models", { p_provider: provider, p_models: models })` inside try/catch raced against a 3 s timeout; respond `{ ok:true, models, stored }` where `stored` is true only when the call returned without error. Do not change failure responses, authentication or timeouts.
2. **Load the table (L5).** In `AiSettingsPage.jsx` load `list_ai_models()` (no argument) with the page data, keep `aiModels` (all providers) in state, and reload it after Load models, Add model and Remove. Each `ProviderCard` receives that provider's rows.
3. **Dropdowns (L5).** Replace the Model `<input>` + `<datalist>` with a required `<select className="select">`: disabled first option "Select a model…", then the provider's `is_available` rows (`model_id`), and the saved value as an extra option when missing from the list (suffix " (not in list)") or unavailable (" (unavailable)"). Replace the Fallback input with a `<select>` whose first option is "None" (empty value), same option rules. Remove the datalist, every model-name placeholder (`gemini-2.5-flash`, `claude-haiku-5-5`, `gpt-4o-mini`, `model name`) and any hard-coded model string; `grep -rniE "gemini-[0-9]|claude-|gpt-" web/src/admin/AiSettingsPage.jsx` must find nothing.
4. **Load, add, remove (L5).** The existing Load models button keeps calling `test-ai` with `action: 'list_models'`, then reloads `aiModels` and shows "N models loaded" (or the existing failure text; if `stored === false` say "Loaded, but couldn't be saved for next time."). Add an "Add model" row: text input (`maxLength={100}`, `aria-label="Model name"`) plus button calling `add_ai_model`, then reload and select it in the Model dropdown. Show a "Remove" button when the selected Model or Fallback value is a manual row (`source === 'manual'`) calling `remove_ai_model`. Empty-state hint under the dropdown: "Click Load models to fill this list, or add a model name." Map the four error messages from L5. Saving still goes through `set_ai_provider` / `set_ai_fallback_model` unchanged (L6); the Save button is disabled until a model is selected.
5. **Node check (L8).** Scratchpad script only: with a mocked client, `list_models` handler logic calls `sync_ai_models` with provider and ids and still returns the models with `stored:false` when the sync throws. Paste the output in Result. If the handler cannot be imported in node, extract nothing into the repo; replicate the call pattern in the script and say so.
6. **SPEC.md.** In the AI section describe the `ai_models` table (source, availability, no seed), that Load models stores the provider's list, the dropdowns, Add/Remove for manual models, and that nothing hard-codes model names; add `ai_models` to the data model list.
7. **RESULT.md.** One row per acceptance checkbox in `00-README.md`: verified or "not verified (needs DB/deploy/provider key)" with evidence and exact manual steps (apply the migration, `npx supabase functions deploy test-ai`, open `/admin/ai`, Load models, pick, Save, Test). Row 1 and DB rows depend on 12/01 running in parallel: mark not verified and reference its Result. Only build, grep, static and node facts may be marked verified. Do not tick Status boxes for 12/01.

## Done when
- `cd web && npm run build` passes.
- `grep -rniE "datalist|gemini-[0-9]|claude-haiku|gpt-4" web/src/admin/AiSettingsPage.jsx` finds nothing.
- The `list_models` failure responses and the other actions of `test-ai` are unchanged (state how you checked by reading the diff).
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
Changed: `supabase/functions/test-ai/index.ts` (new `syncModels` helper; `list_models` now returns `{ ok:true, models, stored }`; nothing else touched, checked by reading the diff: the failure path `fail(e)`, auth, timeouts and the `test` action are untouched), `web/src/admin/AiSettingsPage.jsx` (dropdowns, `list_ai_models` loaded on the page and reloaded after Load/Add/Remove, Add model row, Remove buttons for manual selected values, four error messages, Save disabled until a model is chosen; invokeError, TEST_REASONS, status pills, ErrorLog kept), `web/src/styles.css` (`aim-` block), `SPEC.md`, `docs/plans/12-ai-models-table/RESULT.md`.
Checks: `cd web && npm run build` PASS; `grep -rniE "datalist|gemini-[0-9]|claude-haiku|gpt-4|claude-|gpt-"` on AiSettingsPage.jsx finds nothing PASS; node check (scratchpad `sync.mjs`, replicates the call pattern because the Deno handler is not importable) PASS: sync called with `{p_provider, p_models}`, `stored:false` on throw, on rpc error and on a 3 s timeout.
Not run: DB, Deno, browser, provider checks (see RESULT.md).
Notes: `add_ai_model` is called with `p_label: null`; Remove shows one button per distinct manual selected value ("Remove <id>"). Page-level `list_ai_models()` failure leaves dropdowns empty (saved value still shown) without blocking the page.
