# Plan 08 result

| Acceptance item | State | Evidence / manual steps |
|---|---|---|
| Wrong model name shows reason plus `(HTTP 404: ...)`; wrong key shows 401/403 detail | Not verified (needs deploy/provider key) | Node mock confirms 404 gives kind `model`, status 404, detail = provider message. Manual: `npx supabase functions deploy test-ai`, open `/admin/ai`, save a Gemini key with model `nope`, click Test; then a wrong key. |
| No detail/status/provider text in `generate-review` responses or logs | Verified (grep/static) | `grep -n "detail\|status" supabase/functions/generate-review/index.ts` only matches the `json()` helper's HTTP status param; catch and log lines unchanged. |
| API key never appears in returned `detail` | Verified (node mock) | Mock echoing `test-key-1234` in body and in `?key=` yields `***` and no key. |
| Load models on Gemini fills suggestions with `generateContent` models | Not verified (needs deploy/provider key) | Node mock verifies filtering and `models/` stripping. Manual: deploy `test-ai`, `/admin/ai`, Gemini card, Load models, check the Model input suggestions. |
| Load models works for Claude and OpenAI-compatible | Not verified (needs deploy/provider key) | Mock verifies OpenAI-style parsing (sorted, unique). Manual: Load models on each card with a real key. |
| 5xx then 200 succeeds; two 5xx fail; 4xx not retried | Verified for the adapter (node mock); end-to-end not verified | Mock: 503,200 gives text after 2 calls; 503,503 throws `unavailable` after 2; 400 throws after 1. Manual: `npx supabase functions deploy generate-review`, exercise with a real provider. |
| `SPEC.md` mentions listing, admin-only detail, single retry | Verified (static) | Updated the `test-ai` paragraph in section on AI review drafts. |
