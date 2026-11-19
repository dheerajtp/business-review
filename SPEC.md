# TapReview: NFC Feedback Platform, v1 Spec

Status: Implemented in plans `docs/plans/01-category-subcategory` (categories → subcategories → companies) `docs/plans/02-keyword-library` (global keyword library, chosen per branch) and `docs/plans/04-company-keywords` (company-level keywords inherited by branches). Migrations `supabase/migrations/20261117000001_taxonomy.sql` and `supabase/migrations/20261118000001_keyword_library.sql` are written but not yet applied by the owner; database tests (`supabase/tests/rls.sql`) and browser checks have not been run. See `docs/plans/01-category-subcategory/RESULT.md` and `docs/plans/02-keyword-library/RESULT.md`. Plan `docs/plans/06-ai-review-generation` adds optional AI review drafts: migration `supabase/migrations/20261121000001_ai_review.sql` (needs Supabase Vault; apply after `20261120000001_company_keywords.sql`), Edge Functions `generate-review` and `test-ai`, and the `/admin/ai` page. Not yet applied or deployed by the owner; database tests, Deno, browser and real provider checks have not been run. See `docs/plans/06-ai-review-generation/RESULT.md` for the runbook and known gaps. Stack is `react-supabase` (STACK_CONFIG.md). No custom Node backend (the AI calls run in Supabase Edge Functions).

## 1. Objective

Customers tap an NFC card or scan a QR code at a branch, rate it 1-5, tap the keywords that describe their visit (up to 10 from that branch's list), edit the review text that is drafted from them (or, where the owner has enabled AI, a draft the customer asks an AI provider to write from the rating and keywords; the customer edits it and posts it themselves), and are offered the branch's Google review link. Ratings below 4 are also shown to the company as complaints. Goal: more Google reviews per branch while giving managers a private feedback channel.

Built for one client (a group of 5-30 branches across several business types), implemented multi-tenant.

## 2. Roles

| Role | Can do |
|---|---|
| Super Admin | Manage the taxonomy (categories and subcategories: create, rename, archive/restore); the global keyword library at `/admin/keywords` (create, edit, archive/restore); choose each branch's keywords (up to 10); companies (category then subcategory), branches (incl. Google Place ID), Business Admin accounts; view all feedback; configure the AI review provider at `/admin/ai` (provider, model, base URL, write-only API key, Test, Remove key, active provider, enable, daily limit) |
| Business Admin | One company. View that company's branches and feedback only (filter by branch, rating < 4, 1-2 star highlighted). Read-only on feedback. Can change their company's keywords and the keyword overrides of its own branches at `/business/keywords`. Cannot edit the taxonomy, the keyword library, company/branch details, or the AI settings (`/admin/ai` and its RPCs are refused) |
| Customer | No login. Open `/f/{slug}`, submit feedback. When AI review is enabled and keywords are picked, may ask for an AI draft ("Write my review with AI") and edit it before posting |

## 3. Data model (additive, new project)

- `categories`: id, name (unique, case-insensitive), description, sort_order, is_active, created_at
- `subcategories`: id, category_id → categories, name (1-80, unique per category, case-insensitive), sort_order, is_active, created_at
- `keywords`: id, label (1-60, unique across the whole library, case-insensitive), category_id → categories (nullable; null = General), sort_order, is_active, created_at. One global library: keywords do not belong to a subcategory. Labels are neutral aspects ("Friendly staff", "Value for money") that work for good and bad ratings
- `branch_keywords`: branch_id → branches, keyword_id → keywords, position (1-10), primary key (branch_id, keyword_id), unique (branch_id, position). A branch's picks, in the order the Super Admin (or Business Admin) chose them. Written only through the `set_branch_keywords` RPC
- `company_keywords`: company_id → companies, keyword_id → keywords, position (1-10), primary key (company_id, keyword_id), unique (company_id, position). A company's default keywords, in picked order. Written only through the `set_company_keywords` RPC
- `companies`: id, name, subcategory_id → subcategories (required), is_active, created_at. The category is derived: `companies → subcategories → categories`
- `branches`: id, company_id, name, slug (unique, random, non-guessable), google_place_id, is_active
- `profiles`: user_id (= auth.users.id), role (`super_admin` | `business_admin`), company_id (null for super admin)
- `feedback_submissions`: id, branch_id, company_id (denormalised for RLS), rating (1-5), keywords (jsonb array of `{id,label}` snapshots, in the order the customer picked them, so labels survive later edits), comment, contact (optional), clicked_google (bool), created_at
- `ai_settings` (plan 06): singleton row (`id` boolean primary key, `check (id)`), `active_provider` (`gemini` | `anthropic` | `openai` | `custom`, nullable), `is_enabled` (default false), `daily_limit` (default 2000, 1-100000), `updated_at`
- `ai_providers` (plan 06): one row per provider (`gemini`, `anthropic`, `openai`, `custom`): `model` (1-100 chars), `base_url` (nullable; required for `custom`, optional for `openai`, null for the others), `secret_id` (uuid of the Supabase Vault secret `ai_key_<provider>`), `key_hint` (last 4 characters of the key, for display only), `updated_at`. The key itself is never stored in a table
- `ai_generation_log` (plan 06): id, branch_id → branches, client_hash (first 32 hex chars of SHA-256 of the client address, or empty), created_at. Used only for rate limits; rows older than 7 days are deleted by the rate-limit function

`ai_settings`, `ai_providers` and `ai_generation_log` have RLS on, all privileges revoked from `anon` and `authenticated`, and no direct grants to any role. They are reached only through the RPCs in section 6.

Seed (in the keyword library migration, idempotent): the 8 categories, 29 subcategories and their structure from plan 01 are unchanged. The keyword library is replaced by a global set of 69 keywords: 12 General (category null), 8 for Restaurants & Cafes and 7 for each other category. Categories: Restaurants & Cafes, Retail, Healthcare, Beauty & Wellness, Hotels & Stays, Automotive, Education, Fitness. No branch picks are seeded.

No hard delete anywhere: taxonomy rows and keywords are archived with `is_active = false`. Taxonomy tables and `keywords` have no `delete` grant. Archiving a keyword keeps its `branch_keywords` rows; the keyword is then hidden from the customer form and from pickers. `branch_keywords` has no direct write grant for any role; its rows change only through `set_branch_keywords`.

Indexes: `feedback_submissions(company_id, created_at desc)`, `(branch_id, created_at desc)`, `(company_id, rating)`; `branches(slug)`; `subcategories(category_id)`; `keywords(lower(label))` (unique); `keywords(category_id, is_active)`; `branch_keywords(keyword_id)`; `companies(subcategory_id)`.

Removed: `questions`, `question_requests`, `companies.category_id`, `feedback_submissions.answers`, `keywords.subcategory_id` (and the per-subcategory keyword list). The plan 01 migration wiped existing companies, branches, feedback and Business Admin logins; Super Admin accounts are kept. The keyword library migration deletes the plan 01 keyword rows before seeding the global library; `feedback_submissions.keywords` snapshots are untouched.

## 4. Customer flow (`/f/{slug}`, anonymous, mobile-first)

1. Page calls one RPC `get_feedback_form(slug)` returning branch name, company name, Google Place ID, category name, subcategory name and the branch's picked keywords (`[{id,label}]`, active only, in the picked order, at most 10). A branch with no picks gets an empty list, with no fallback. Inactive branch, company, subcategory or category returns not-found.
2. Customer picks 1-5 stars (mandatory). The keyword chips appear directly under the stars for every rating (hidden only when the branch has no keywords), and the customer taps up to 10. The selection persists when the rating changes. The review text is composed on the client from the company name, the rating and the chosen keywords (`web/src/customer/reviewText.js`, rules in `docs/plans/02-keyword-library/00-README.md` K8). It prefills the comment box, is re-composed on rating or keyword change until the customer edits the text by hand, and is a draft the customer copies. Nothing is auto-posted. If rating < 4, an optional contact field (phone or email) is shown.
   - **AI draft (plan 06, optional).** The form RPC returns `ai_enabled` (true when AI is enabled and the active provider has a saved key). When it is true and at least one keyword is picked, a "Write my review with AI" button appears under the chips. It calls the Edge Function `generate-review` with `{slug, rating, keyword_ids}` only (never the comment or contact). On success the text replaces the comment box, is marked as edited (so the template stops overwriting it), the button becomes "Regenerate", and the note "Suggested by AI. Edit it so it matches your visit." is shown. On failure the current text is kept with "Couldn't generate right now. You can edit the text below." (429: "Please try again in a few minutes."). The template draft stays the default and the fallback; the button is hidden when AI is off.
3. Submit calls RPC `submit_feedback(slug, rating, keyword_ids, comment, contact)`; the server validates everything and returns the submission id. Anonymous users have no direct table access.
4. Thank-you screen, **same for every rating**:
   - "Post on Google" button → `https://search.google.com/local/writereview?placeid=<PLACE_ID>`, plus a one-tap "Copy my comment".
   - Rating < 4: a card **side by side with equal visual weight** saying the feedback has gone to the manager. The Google button is never hidden or demoted.
5. Google button tap calls RPC `mark_google_click(submission_id)`, which sets `clicked_google` (best-effort, never blocks the redirect).

Google policy: no gating. Every rating sees the Google link at the same prominence.

## 5. Admin features

**Super Admin**
- Taxonomy screen at `/admin/categories`: category list; selecting a category shows its subcategories. At each level: create, rename, archive/restore (no delete). Archived items are shown dimmed here and hidden from company pickers. This page shows categories and subcategories only.
- Keyword library at `/admin/keywords` (sidebar "Keywords" under Set up): table of label, category (or General) and status; search; filter (All / General / each category / Archived); add and edit (label 1-60, optional category); archive/restore; new keywords take the next sort position. A duplicate label shows "That keyword already exists." Archived keywords are shown dimmed here and hidden from pickers and the customer form.
- Branch keyword picker (shared component `web/src/shared/BranchKeywordsPicker.jsx`) on the branch screens (`BranchForm`, `CompanyDetailPage`): a searchable checklist of active keywords, filtered by default to the company's category plus General, with a "Show all" toggle. Counter `n / 10`; unchecked items are disabled at 10; pick order is the saved position. Save calls `set_branch_keywords`.
- Company keywords: the company create/edit dialog has a "Review keywords" checklist (same shared `KeywordChecklist`, max 10, default filter = the selected category plus General). Save creates or updates the company, then calls `set_company_keywords`; if the keyword save fails the dialog stays open with "Company saved, but keywords could not be saved: ... Try again." and a retry updates rather than duplicates. Skipping keywords is allowed. Branch screens label their picker "Branch override: Leave empty to use the company's keywords."
- Company create/edit: Category select, then Subcategory select filtered to that category (both required; active items, plus the company's current subcategory). Only categories with at least one active subcategory are offered (plus the company's current category). A category without subcategories is not assignable to companies; the Categories screen marks it "No subcategories". Company list and detail show `Category › Subcategory`.
- Company and branch CRUD. Branch screen shows the NFC URL `https://<app-domain>/f/{slug}` (for writing to the tag) and a downloadable QR code.
- NFC writing limit: Web NFC works only in Chrome on Android over HTTPS. Other devices use the hand-off QR (opens the branch's NFC & QR dialog on an Android phone via `?nfc=<branchId>`), the free NFC Tools app (iPhone) or a USB reader with NFC Tools desktop. Reading a written card works on any phone. A native app that writes tags is out of scope.
- Create Business Admin logins (Edge Function, since this needs the service-role key).
- Feedback list with keyword chips per submission.
- AI review settings at `/admin/ai` (sidebar "AI review" under Set up; lazy route). Provider select (Gemini, Claude (Anthropic), OpenAI (GPT), Custom (OpenAI-compatible)). Per provider: model (free text, editable, no allow-list), base URL (custom required, OpenAI optional, hidden for the others), and an API key field that is write-only: the page shows "Saved, ending ####" from `key_hint`, an empty field keeps the saved key, and the typed key is held only in component state and cleared after Save. Buttons: Save (`set_ai_provider`), Test (`test-ai`, shows the sample or a plain reason), Remove key (`clear_ai_provider_key`, with confirm). Global: active provider, "Enable AI reviews" toggle, daily limit (`set_ai_settings`). Enabling is refused unless the active provider has a saved key. Data comes from `get_ai_settings`, which never returns a key or secret id.
- Edge Function deploy and secrets are operator tasks: Supabase Vault must be enabled; see the runbook in `docs/plans/06-ai-review-generation/RESULT.md`.

**Business Admin**
- Keywords at `/business/keywords` (sidebar "Keywords" under Set up): a "Company keywords" card (their company's default list, `CompanyKeywordsPicker`) and below it a "Branch override" picker per branch (note: "Leave empty to use the company's keywords."), each with a "Clear override" button. They can change their own company's keywords and their own branches' overrides, never another company's. The company's category is read from `companies`.
- Dashboard: submissions list with branch filter, rating filter, date range, "needs attention" view (< 4 stars, 1-2 highlighted), keyword chips per submission. Basic counts and average rating per branch.

## 6. Security

- RLS on every table. Business Admin: `company_id = (select company_id from profiles where user_id = auth.uid())`. Super Admin: role check via the same `profiles` row. Taxonomy tables (`categories`, `subcategories`) and `keywords`: `select` for any role with a profile; `insert/update` only for Super Admin; no `delete` grant; no table grants to `anon`. `branch_keywords`: `select` for Super Admin (all rows) and Business Admin (rows of branches in their company); no insert/update/delete grant for any role; nothing for `anon`. Customers: RPC only (`security definer`, fixed `search_path`).
- Branch keyword writes go only through `set_branch_keywords(p_branch_id, p_keyword_ids)`: `security definer`, fixed `search_path`, execute granted to `authenticated` only. The role is checked server-side: Super Admin, or Business Admin whose company owns the branch; otherwise `42501 forbidden`. Unknown branch → `P0002`. Null means no picks; duplicate ids are merged; more than 10 distinct ids → `22023 too many keywords`; any id that is not an active keyword → `22023 unknown keyword`. The branch's rows are replaced in one transaction with positions 1..n.
- Company keyword writes go only through `set_company_keywords(p_company_id, p_keyword_ids)` with the same rules as the branch RPC: Super Admin, or Business Admin whose own company it is, otherwise `42501 forbidden`; unknown company → `P0002 unknown company`; at most 10 distinct ids (`22023 too many keywords`), all active (`22023 unknown keyword`); atomic replace with positions 1..n. `company_keywords` has no direct write grant for any role.
- Override rule: a branch with its own `branch_keywords` rows shows only those; a branch with none inherits the company's `company_keywords`. Clearing a branch's list (saving it empty) returns it to the company's list. No merging of the two lists. The customer form and `submit_feedback` use this effective list, so the review page shows the effective list.
- Role/company are read from `profiles`, never from client input or JWT claims the user can edit.
- Service-role key only in the Edge Function, never in the frontend.
- Server-side validation in `submit_feedback`: rating 1-5; text length caps (comment 2000, contact 200); at most 10 distinct keyword ids (duplicates merged); every keyword id must be an active keyword picked for that branch (`22023 unknown keyword`, replacing the old answer validation); reject inactive branches.
- Abuse: simple flood control of 30 submissions per branch per client address per 10 minutes (`54000`). No CAPTCHA in v1 (section 11, item 4). Render all user text as plain text (no HTML).
- Customer data is personal data if contact is given; keep contact optional and visible only to that company.

**AI review drafts (plan 06)**
- Provider key: stored only in Supabase Vault (secret name `ai_key_<provider>`). The table keeps only `secret_id` and `key_hint`. Admin RPCs `set_ai_provider`, `clear_ai_provider_key`, `set_ai_settings` and `get_ai_settings` are `security definer`, fixed `search_path`, execute for `authenticated` only, and raise `42501 forbidden` unless the caller is `super_admin`. `get_ai_settings` never returns a key or `secret_id`. A null or empty key on save keeps the existing key; a new key replaces it. The key is write-only in the UI.
- Runtime RPCs `get_ai_runtime`, `get_ai_provider_runtime`, `get_review_context` and `log_ai_generation` are executable by `service_role` only. They are not callable by `anon` or `authenticated`.
- Base URL guard (SQL `ai_valid_base_url`, repeated in the adapter): `https://` only, at most 300 characters, no `localhost`, no IPv4 or IPv6 literal, no `.local` or `.internal` host, no credentials, trailing slash stripped. Redirects are not followed by the adapter.
- Edge Function `generate-review` (anon key, default JWT verification on; the customer cannot choose the provider, model, prompt or length). Input: `slug`, `rating` (1-5 integer), `keyword_ids` (at most 10, validated against the branch's effective list by `get_review_context`); body at most 4 KB (`413`). Errors: `400` invalid input or keywords, `404` not found, `405`, `429 rate_limited`, `503 ai_unavailable`, `502 ai_failed` (any provider error, timeout or empty output; no provider detail), `500`.
- Rate limits (`log_ai_generation`): at most 6 generations per branch and client address per 10 minutes, and at most `daily_limit` (default 2000) per branch-wide 24 hours. The client address is hashed (SHA-256, first 32 hex chars); the key and prompt are never logged or returned.
- Edge Function `test-ai` (Super Admin only; `401` not signed in, `403` not Super Admin). Sends a fixed sample through the same adapter with an 8 s timeout and returns `{ok, sample}` or `{ok:false, reason}` where `reason` is `no_key`, `auth`, `model`, `network`, `timeout` or `unknown`. Never echoes the key or raw provider messages.
- Provider adapters call only the fixed hosts for Gemini, Anthropic and OpenAI, or the saved base URL for OpenAI and custom. Timeout 8 s.
- **Data sent to the provider:** business (company) name, branch name, category and subcategory names, the rating, and the chosen keyword labels, plus a fixed instruction. Never customer contact details, the comment text, the branch slug, or any submission data.
- **Policy (A14):** AI output is a draft the customer must edit. The app never posts or submits it. Customer-facing text calls it a suggestion and never says it is the customer's own words, because Google's review policies require reviews to reflect a real experience.

## 7. Performance

Form load under 1.5s on mobile: one RPC call, small JS bundle for the `/f/` route (lazy-load admin code), no auth round-trip. Caching beyond this only if measured to be needed.

## 8. Out of scope (v1)

AI keyword selection or rephrasing (AI is used only for the customer's review draft, plan 06), per-company AI keys, editable AI prompts or tone options, AI streaming, AI usage or cost dashboards, multi-language AI drafts, automatic AI generation on every change, AI key rotation reminders, per-company private keyword libraries, keyword bulk import, keyword SEO rank or usage reports, email/SMS alerts, customer accounts, auto-posting to Google, Business Admin editing the taxonomy, the keyword library or branch details, deleting taxonomy items or keywords (archive only), reordering keywords in the UI (sort order is set on create), non-English labels.

## 9. Acceptance criteria

1. Opening `/f/{slug}` of an active branch renders that branch's active picked keywords, in picked order (at most 10), with category and company names; a branch with no picks shows no chips. Unknown or inactive slug, and an archived subcategory or category, show not-found.
2. A valid submission is stored with the correct branch/company and `{id,label}` keyword snapshots; invalid payloads (rating 0 or 6, a keyword not picked for that branch, an archived keyword, more than 10 keyword ids, oversized text) are rejected.
3. Thank-you screen shows the Google link for ratings 1-5; for < 4 it also shows the manager card at equal prominence.
4. Business Admin A cannot read, update or delete company B's submissions or branches, even by calling Supabase directly (denied-path tests). Business Admin cannot write categories, subcategories or keywords, and cannot set the keywords of another company's branch (`42501`). Business Admin can set the keywords of their own company's branches.
5. Anonymous users cannot `select` from any table.
6. An archived keyword does not appear on the customer form or in the pickers, except dimmed in a branch's list when it is already picked. An archived subcategory or category makes its form not-found. Archived categories, subcategories and keywords stay visible (dimmed) in the Super Admin screens.
7. Super Admin can create a category, subcategory, keyword (in the library), company (Category then Subcategory), branch and Business Admin login, set up to 10 keywords for a branch, and download the QR.
8. Form is usable on iOS Safari and Android Chrome; load under 1.5s on a throttled mobile profile.
9. AI review (plan 06): with AI off or unconfigured the form shows no AI button. With AI enabled and keywords picked, the button fills the editable comment box and "Regenerate" works. Provider failures, timeouts and rate limits keep the template text with a friendly message. The 7th generation in 10 minutes for the same client and branch is refused (`429`), a keyword outside the branch's list is refused (`400`), and a Business Admin cannot open `/admin/ai` or call its RPCs. Full checklist: `docs/plans/06-ai-review-generation/00-README.md`. Status in this environment: not verified (needs a database, browser and provider key).

## 10. Testing plan

Run against a real Supabase project (or local `supabase start`): RLS allow/deny matrix per role and table (`supabase/tests/rls.sql`, including keyword library seed counts, `set_branch_keywords` rules and the submit keyword cap), RPC validation cases, an end-to-end customer flow in a browser at a mobile viewport, and a Lighthouse/throttled load check. For plan 06, `supabase/tests/rls.sql` covers the AI tables and RPCs (no direct access, `42501` for non-super-admins, keys never in output, base URL guard, enable-without-key refused, `get_review_context` and the rate limits) and must print `ALL RLS TESTS PASSED`. Provider checks use a real key per provider, run by the owner through `/admin/ai` Test.

## 11. Open questions (defaults assumed, please confirm)

1. **Private "tell the manager" option:** I assumed every low-rating submission is already visible to the manager, so the card is an acknowledgement, with an optional contact field on the form. If you want a separate extra step, say so.
2. **Slug:** a short random slug, not the raw database UUID in the URL. App domain is TBD.
3. **Auth method:** email + password through Supabase Auth, Super Admin seeded manually.
4. **Spam control:** simple rate limit only. No CAPTCHA in v1.
5. **Languages:** English only in v1. Confirm that the client does not need local languages on the customer form.
6. **Data retention:** keep all submissions indefinitely.
