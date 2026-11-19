# 06 acceptance evidence

Verified here: web build, greps, static review of SQL and Edge Function code, and node checks with mocked fetch (from slice 02). No database, Supabase CLI, Deno, browser or AI provider key was available, so every runtime row is marked not verified. The owner runs the manual steps below.

## Checklist (`00-README.md` Acceptance checklist)

| Acceptance item | Status | Evidence / manual steps |
| --- | --- | --- |
| After the migration, `rls.sql` prints `ALL RLS TESTS PASSED`; no role can read the AI tables directly and no RPC output ever contains an API key | Not verified (needs DB) | Static: migration 20 `$$` blocks balanced, RPC signatures match A2/A3, `grep -rn "test-key" supabase` only in `rls.sql` (01 Result). `rls.sql` AI sections written but not run. Manual: on a plain Postgres test database, run `supabase/tests/00_stubs.sql`, the migrations in order, then `supabase/tests/rls.sql`; expect `ALL RLS TESTS PASSED`. Do not run the stubs on the hosted project, which has real Vault. |
| `/admin/ai`: Super Admin can save, see "Saved, ending ####", Test, Remove key, pick active provider and enable; Business Admin cannot open the page or call the RPCs | Not verified (needs browser + DB) | Static: `web/src/admin/AiSettingsPage.jsx` is lazy-routed in the Super Admin group; `npm run build` PASS; no console, localStorage or sessionStorage use in the page (03 Result). Manual: sign in as Super Admin at `/admin/ai`, save a fake key then a real one, check the field shows "Saved, ending ####" and the key is gone after Save, Test, Remove key (confirm dialog), set active provider, enable. Sign in as Business Admin, open `/admin/ai` (must be refused) and confirm `get_ai_settings` returns 42501. |
| Switching between Gemini, Claude, OpenAI and a custom OpenAI-compatible URL works without code changes (verified per provider with a real key by the user) | Not verified (needs provider keys) | Node with mocked fetch (02 Result): request shape per adapter matches A6 (gemini URL and `x-goog-api-key`; anthropic headers; openai `max_completion_tokens` with no temperature; custom `max_tokens` and `temperature: 0.8`, trailing slash stripped). Real calls not made. Manual: for each provider, save its key and model on `/admin/ai`, press Test, expect "Sample" text. Custom: base URL of the OpenAI-compatible service. |
| With AI off or unconfigured, the review page shows no AI button and works as before | Not verified (needs browser + DB) | Static: AI block in `FeedbackFormView.jsx` is guarded by `form.ai_enabled === true` (04 Result); `get_feedback_form.ai_enabled` is false until enabled with a key (01 Result). Build PASS. Manual: open a branch's `/f/{slug}` with AI disabled and confirm no button and the template draft still works. |
| With AI enabled and keywords picked, the button fills the editable box with a draft that uses the rating and keywords; "Regenerate" works; a manual edit is kept | Not verified (needs browser + DB + provider key) | Static: `generate()` calls `supabase.functions.invoke('generate-review')` with `{slug, rating, keyword_ids}`, 10 s client timeout (04 Result, 02 Result). Prompt text per A7 checked in node (02 Result). Manual: enable AI, pick keywords on a mobile viewport, press "Write my review with AI", check the text and the note "Suggested by AI. Edit it so it matches your visit.", press "Regenerate", edit the text by hand, change the rating and confirm the edited text is kept. |
| A provider failure, timeout or rate limit leaves the template text in place with a friendly message and never exposes provider details | Not verified (needs browser + provider) | Node with mocked fetch: 401/403 → `auth`, 400/404 → `model`, 429/500 → `unknown`, fetch throw → `network`, AbortError → `timeout` (02 Result). Edge Function maps any provider error to `502 ai_failed` with no detail (static). Client messages: 502/503 "Couldn't generate right now…", 429 "Please try again in a few minutes." (static, 04 Result). Manual: with a bad key or a bad model name, press the button and confirm the text is kept and no provider message is shown. |
| The 7th request in 10 minutes from the same client for a branch is refused (429); a keyword not in the branch's list is refused (400); the daily limit stops generation | Not verified (needs DB + deployed functions) | Static: `log_ai_generation` refuses at ≥ 6 rows in 10 minutes for the pair and at ≥ `daily_limit` in 24 hours (migration lines ~294–320); `get_review_context` raises `22023` for an id outside the effective set, mapped to `400 invalid_keywords` (02 Result). `rls.sql` has the 6-then-refuse and daily-limit cases (01 Result) but they have not been run. Manual: call `generate-review` 7 times from one client, send a keyword id from another branch, set `daily_limit` to 1 and call once more. |
| `http://`, localhost, IP-literal and `.internal` base URLs are rejected when saving a custom provider | Not verified (SQL and UI not run) | Node: `isValidBaseUrl` in `_shared/urlGuard.js` returns false for `http://x.com`, `https://localhost/v1`, `https://10.0.0.1/v1`, `https://[::1]/`, credentials, `.internal`, `.local`, query and fragment, and true for `https://api.example.com/v1/` (02 Result). SQL `ai_valid_base_url` is checked by `rls.sql` (not run). Manual: on `/admin/ai`, save a custom provider with each value and confirm the save is refused. |
| `SPEC.md` and the runbook describe the provider setup, the Vault requirement, deploying the two Edge Functions and the data sent to the provider (business name, branch name, category, rating, keywords; no customer contact or free text) | Verified (grep) | `SPEC.md` sections 1, 2, 3, 4, 5, 6, 8, 9 (item 9), 10 updated; grep for `ai_settings`, `ai_providers`, `ai_generation_log`, `Vault`, `generate-review`, `test-ai` and the data list returns the new text. The runbook is in the Runbook section below. |

## Runbook (owner steps, in order)

Nothing in this list has been run. The provider names and model placeholders (`gemini-2.5-flash`, `claude-haiku-5-5`, `gpt-4o-mini`) are not checked against live provider documentation; confirm the model id before saving.

1. **Enable Vault.** In the Supabase dashboard, enable the Vault extension (`supabase_vault`, for example with `create extension if not exists supabase_vault;` in the SQL editor). The migration calls `vault.create_secret` and `vault.update_secret`, so it fails without Vault. Confirm the exact dashboard path against Supabase docs.
2. **Apply the migration** `supabase/migrations/20261121000001_ai_review.sql`. It must run after `20261120000001_company_keywords.sql` (apply the earlier migrations first, for example with `supabase db push`).
3. **Deploy the Edge Functions** from the repo root:
   ```
   supabase functions deploy generate-review
   supabase functions deploy test-ai
   ```
   Both read `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from the function environment. Do not put the service-role key in the frontend or in any file.
4. **Run the database tests** on a plain Postgres test database only (see the first checklist row), expecting `ALL RLS TESTS PASSED`.
5. **Open `/admin/ai`** as a Super Admin.
6. **Save a key**: choose a provider, enter the model, enter the base URL (custom only; OpenAI optional), enter the key and press Save. The page then shows "Saved, ending ####". The key is not shown again.
7. **Test** the provider. Expect the sample text. If not, the reason is shown (`no_key`, `auth`, `model`, `network`, `timeout`, `unknown`).
8. **Set the active provider**, then turn on "Enable AI reviews" and press Save. Enabling is refused without a saved key for the active provider.
9. Check one branch's `/f/{slug}` page on a phone (see checklist rows).

Data sent to the provider per review: business (company) name, branch name, category and subcategory names, rating, and the chosen keyword labels. Nothing else.

## Known gaps

- **Test error message:** if the `test-ai` invoke itself fails (network or non-2xx from the function), the page shows only "Test failed." with no reason. The reason text is shown only when the function returns `{ok:false, reason}` (03 Result).
- **"Saved." message lost on remount:** the provider card remounts when `updated_at` or `has_key` changes, so the "Saved." message is replaced by the refreshed card (03 Result).
- **Shared rate-limit bucket:** when `client_hash` is null, or there is no `x-forwarded-for` header (hash of the empty string), all such callers for a branch share one 10-minute bucket. `log_ai_generation` matches with `is not distinct from` (01 and 02 Results).
- **Keyword error wording:** `get_review_context` uses `unknown keyword` (22023) for more than 10 distinct ids, as A3 specifies. It is not the `too many keywords` wording used by the admin RPCs (01 Result).
- **Model names unverified:** the placeholder model names in the admin UI and in this runbook are not checked against live provider docs (03 Result, this slice).
- **Customer timeout mismatch:** the browser waits 10 s; the Edge Function and adapter use 8 s (02 and 04 Results). The browser may show the failure message after the function has already returned a 502.
- **Not run in this environment:** `rls.sql` and the migration (no Postgres or Supabase CLI), Deno type or runtime checks and `supabase functions serve`, browser checks of `/admin/ai` and the customer button, and any real provider call. All remain for the owner.
- **Redirect handling:** provider fetches set `redirect: "error"`, so a redirect becomes a `network` failure. Checked with a mocked fetch only (02 Result follow-up).
- **Log retention:** rows in `ai_generation_log` older than 7 days are deleted only when `log_ai_generation` runs (01 Result).
