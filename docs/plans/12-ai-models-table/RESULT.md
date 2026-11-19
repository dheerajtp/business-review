# Plan 12 — Acceptance evidence

Not verified in this environment: no database, Deno, browser or provider key. Slice 01 (migration, RLS tests) ran in parallel; see its Result in `01-table-rpcs-tests.md`.

Runbook: apply `supabase/migrations/20261126000001_ai_models.sql` (`npx supabase db push`), run `supabase/tests/rls.sql`, `npx supabase functions deploy test-ai`, open `/admin/ai` as Super Admin, Load models, pick, Save, Test.

| # | Acceptance item | Status | Evidence / manual steps |
|---|---|---|---|
| 1 | After the migration `rls.sql` prints `ALL RLS TESTS PASSED`; no direct table access | Not verified (needs DB; depends on 12/01) | See 12/01 Result. Steps: apply migration, run `supabase/tests/rls.sql`, expect `ALL RLS TESTS PASSED`. |
| 2 | Load models on Gemini stores the list and fills both dropdowns; reload shows them | Not verified (needs DB, deploy, provider key) | Static: `test-ai` `list_models` now calls `sync_ai_models` and returns `stored`; page loads `list_ai_models` on mount and after Load models. Node check of the call pattern (scratchpad): sync called with provider and ids; `stored:false` when it throws, errors or exceeds 3 s. Steps: deploy `test-ai`, save a Gemini key, click Load models, see "N models loaded", reload the page, open both dropdowns. |
| 3 | Model and Fallback are dropdowns; no free text, suggestions or hard-coded names; saved model stays selected | Verified (static) / browser not verified | `grep -rniE "datalist|gemini-[0-9]|claude-|gpt-" web/src/admin/AiSettingsPage.jsx` finds nothing; `cd web && npm run build` passes; saved value added as "(not in list)" or "(unavailable)" option by `modelOptions`. Browser: open `/admin/ai` with a saved model absent from the list and confirm it stays selected. |
| 4 | Add model adds a manual model; Remove deletes it unless in use; loaded models cannot be removed | Not verified (needs DB) | Static: Add calls `add_ai_model` then selects it; Remove buttons appear only for selected manual rows and call `remove_ai_model`; the four error messages are mapped in `rpcError`. Steps: add "x-test", confirm it is selected; Remove it while selected (expect "That model is selected..."), change selection, Remove again; confirm a loaded model shows no Remove button. |
| 5 | Later Load models marks models no longer listed as unavailable, keeps manual ones | Not verified (needs DB, provider; logic is in 12/01 `sync_ai_models`) | Steps: Load models, then (in SQL) insert a synced row not in the provider list, Load models again, confirm it shows "(unavailable)" only when saved and is missing from the dropdown otherwise; manual rows remain. |
| 6 | Custom providers work with manual models when `/models` is missing | Not verified (needs DB, a custom endpoint) | Steps: save a Custom provider with a base URL lacking `/models`, Load models shows the failure text, Add model with a name, select, Save, Test. |
| 7 | `SPEC.md` describes the table and the dropdown | Verified (static) | `SPEC.md` data model list (`ai_models`) and section 5 AI settings bullet updated. |

Do not tick the 12/01 Status box from this file.
