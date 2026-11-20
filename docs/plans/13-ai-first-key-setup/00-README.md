# 13 — First-time AI key setup (fix the Save / Load models deadlock)

Master plan: none · Builds on and amends: [`../12-ai-models-table/00-README.md`](../12-ai-models-table/00-README.md) (L5: Model is a dropdown filled by Load models) and [`../08-ai-diagnostics-and-models/00-README.md`](../08-ai-diagnostics-and-models/00-README.md) (G2: Load models)

## Goal
- A Super Admin can set up a provider that has **no key and no model yet** (Claude, OpenAI, Custom): paste key, Load models, pick a model, Save.
- Today this is impossible. Save needs a model (`disabled={busy || !model}`), the model dropdown is empty until Load models runs, and Load models needs a saved key (`disabled={busy || !hasKey}`). Gemini only works because it was saved before plan 12.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| S1 | **Cause.** `web/src/admin/AiSettingsPage.jsx` ProviderCard: Save is disabled until `model` is set; Load models and Test are disabled until `row.has_key`; `set_ai_provider` and `ai_providers.model` require a non-empty model. No database change is made in this plan. |
| S2 | **Load models accepts an unsaved key.** `test-ai` action `list_models` takes optional body fields `api_key` (string, 8–400 chars, no whitespace) and, for Custom, `base_url`. When `api_key` is present it is used for that one call instead of the saved key, and `base_url` replaces the saved one only for Custom (same `ai_valid_base_url` rule as Save; Gemini and Claude ignore it). The key is never stored, logged, echoed in a response or put in an error log row. Invalid key shape returns the existing `{ ok:false, reason:"auth" }`. Super admin authentication and the 8 s timeout are unchanged. The `test` action ignores `api_key`. |
| S3 | **Sync still stores model names.** After a successful `list_models` with a typed key, `sync_ai_models` runs as today (L4), so the dropdown fills and survives reload. |
| S4 | **UI.** Load models is enabled when `hasKey` **or** the API key box has text (and, for Custom, the Base URL box has text); it sends the typed key and base URL when present. Test stays enabled only with a saved key. Save stays disabled without a model; after Load models the dropdown has options, the admin picks one and Save stores key plus model together. The no-key hint under the model dropdown reads "Paste your API key, then click Load models." when there is no saved key and no typed key. |
| S5 | **Visible reason.** When Save or Load models is disabled by a missing prerequisite, the button keeps its `title` attribute explaining why ("Pick a model first", "Paste an API key first"). |
| S6 | **Tests.** Node mock check in the scratchpad: `list_models` with `api_key` calls the adapter with that key and not the vault key, does not return or log it, rejects `"short"` and a key containing a space with `reason:"auth"`, and still syncs. Without `api_key` behaviour is unchanged. `cd web && npm run build` passes. Deploy and browser checks are reported NOT RUN. |
| S7 | **Out of scope (later).** A "save key only" path without a model, making `ai_providers.model` nullable, auto-loading models on key paste, testing with an unsaved key. |

## Status
- [x] 01 — Function accepts unsaved key; Load models enabled with a typed key; button hints (build and node mock check PASS; deploy, Deno check and browser NOT RUN)

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | none | Sonnet | `supabase/functions/test-ai/index.ts`, `web/src/admin/AiSettingsPage.jsx`, `docs/plans/13-ai-first-key-setup/RESULT.md` |

Apply order for you: `npx supabase functions deploy test-ai`, hard-refresh `/admin/ai`.

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; no real keys anywhere; `cd web && npm run build` must pass; the Edge Function is statically reviewed plus the node mock check (no Deno here); append `## Result` to the slice file. Build on the current contents of every file listed, which plans 08–12 edited.

## Acceptance checklist
- [ ] On the Claude card with no saved key: pasting a key enables Load models; clicking it fills the Model and Fallback dropdowns.
- [ ] After picking a model, Save stores key and model; the card shows "Key saved"; Test then works.
- [ ] The typed key never appears in a response, error log row or the browser after Save (field clears, "Saved, ending …" only).
- [ ] Gemini card behaviour (saved key, saved model) is unchanged.
