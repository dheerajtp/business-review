# TapReview: NFC Feedback Platform, v1 Spec

Status: Implemented in plans `docs/plans/01-category-subcategory` (categories → subcategories → companies) and `docs/plans/02-keyword-library` (global keyword library, chosen per branch). Migrations `supabase/migrations/20261117000001_taxonomy.sql` and `supabase/migrations/20261118000001_keyword_library.sql` are written but not yet applied by the owner; database tests (`supabase/tests/rls.sql`) and browser checks have not been run. See `docs/plans/01-category-subcategory/RESULT.md` and `docs/plans/02-keyword-library/RESULT.md`. Stack is `react-supabase` (STACK_CONFIG.md). No custom Node backend.

## 1. Objective

Customers tap an NFC card or scan a QR code at a branch, rate it 1-5, tap the keywords that describe their visit (up to 10 from that branch's list), edit the review text that is drafted from them, and are offered the branch's Google review link. Ratings below 4 are also shown to the company as complaints. Goal: more Google reviews per branch while giving managers a private feedback channel.

Built for one client (a group of 5-30 branches across several business types), implemented multi-tenant.

## 2. Roles

| Role | Can do |
|---|---|
| Super Admin | Manage the taxonomy (categories and subcategories: create, rename, archive/restore); the global keyword library at `/admin/keywords` (create, edit, archive/restore); choose each branch's keywords (up to 10); companies (category then subcategory), branches (incl. Google Place ID), Business Admin accounts; view all feedback |
| Business Admin | One company. View that company's branches and feedback only (filter by branch, rating < 4, 1-2 star highlighted). Read-only on feedback. Can change the keyword picks of that company's own branches at `/business/keywords`. Cannot edit the taxonomy, the keyword library, or company/branch details |
| Customer | No login. Open `/f/{slug}`, submit feedback |

## 3. Data model (additive, new project)

- `categories`: id, name (unique, case-insensitive), description, sort_order, is_active, created_at
- `subcategories`: id, category_id → categories, name (1-80, unique per category, case-insensitive), sort_order, is_active, created_at
- `keywords`: id, label (1-60, unique across the whole library, case-insensitive), category_id → categories (nullable; null = General), sort_order, is_active, created_at. One global library: keywords do not belong to a subcategory. Labels are neutral aspects ("Friendly staff", "Value for money") that work for good and bad ratings
- `branch_keywords`: branch_id → branches, keyword_id → keywords, position (1-10), primary key (branch_id, keyword_id), unique (branch_id, position). A branch's picks, in the order the Super Admin (or Business Admin) chose them. Written only through the `set_branch_keywords` RPC
- `companies`: id, name, subcategory_id → subcategories (required), is_active, created_at. The category is derived: `companies → subcategories → categories`
- `branches`: id, company_id, name, slug (unique, random, non-guessable), google_place_id, is_active
- `profiles`: user_id (= auth.users.id), role (`super_admin` | `business_admin`), company_id (null for super admin)
- `feedback_submissions`: id, branch_id, company_id (denormalised for RLS), rating (1-5), keywords (jsonb array of `{id,label}` snapshots, in the order the customer picked them, so labels survive later edits), comment, contact (optional), clicked_google (bool), created_at

Seed (in the keyword library migration, idempotent): the 8 categories, 29 subcategories and their structure from plan 01 are unchanged. The keyword library is replaced by a global set of 69 keywords: 12 General (category null), 8 for Restaurants & Cafes and 7 for each other category. Categories: Restaurants & Cafes, Retail, Healthcare, Beauty & Wellness, Hotels & Stays, Automotive, Education, Fitness. No branch picks are seeded.

No hard delete anywhere: taxonomy rows and keywords are archived with `is_active = false`. Taxonomy tables and `keywords` have no `delete` grant. Archiving a keyword keeps its `branch_keywords` rows; the keyword is then hidden from the customer form and from pickers. `branch_keywords` has no direct write grant for any role; its rows change only through `set_branch_keywords`.

Indexes: `feedback_submissions(company_id, created_at desc)`, `(branch_id, created_at desc)`, `(company_id, rating)`; `branches(slug)`; `subcategories(category_id)`; `keywords(lower(label))` (unique); `keywords(category_id, is_active)`; `branch_keywords(keyword_id)`; `companies(subcategory_id)`.

Removed: `questions`, `question_requests`, `companies.category_id`, `feedback_submissions.answers`, `keywords.subcategory_id` (and the per-subcategory keyword list). The plan 01 migration wiped existing companies, branches, feedback and Business Admin logins; Super Admin accounts are kept. The keyword library migration deletes the plan 01 keyword rows before seeding the global library; `feedback_submissions.keywords` snapshots are untouched.

## 4. Customer flow (`/f/{slug}`, anonymous, mobile-first)

1. Page calls one RPC `get_feedback_form(slug)` returning branch name, company name, Google Place ID, category name, subcategory name and the branch's picked keywords (`[{id,label}]`, active only, in the picked order, at most 10). A branch with no picks gets an empty list, with no fallback. Inactive branch, company, subcategory or category returns not-found.
2. Customer picks 1-5 stars (mandatory). The keyword chips appear directly under the stars for every rating (hidden only when the branch has no keywords), and the customer taps up to 10. The selection persists when the rating changes. The review text is composed on the client from the company name, the rating and the chosen keywords (`web/src/customer/reviewText.js`, rules in `docs/plans/02-keyword-library/00-README.md` K8). It prefills the comment box, is re-composed on rating or keyword change until the customer edits the text by hand, and is a draft the customer copies. Nothing is auto-posted. If rating < 4, an optional contact field (phone or email) is shown.
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
- Company create/edit: Category select, then Subcategory select filtered to that category (both required; active items, plus the company's current subcategory). Only categories with at least one active subcategory are offered (plus the company's current category). A category without subcategories is not assignable to companies; the Categories screen marks it "No subcategories". Company list and detail show `Category › Subcategory`.
- Company and branch CRUD. Branch screen shows the NFC URL `https://<app-domain>/f/{slug}` (for writing to the tag) and a downloadable QR code.
- Create Business Admin logins (Edge Function, since this needs the service-role key).
- Feedback list with keyword chips per submission.

**Business Admin**
- Keywords at `/business/keywords` (sidebar "Keywords" under Set up): one picker per branch of their own company. They can change the picks of those branches. The company's category is read from `companies`.
- Dashboard: submissions list with branch filter, rating filter, date range, "needs attention" view (< 4 stars, 1-2 highlighted), keyword chips per submission. Basic counts and average rating per branch.

## 6. Security

- RLS on every table. Business Admin: `company_id = (select company_id from profiles where user_id = auth.uid())`. Super Admin: role check via the same `profiles` row. Taxonomy tables (`categories`, `subcategories`) and `keywords`: `select` for any role with a profile; `insert/update` only for Super Admin; no `delete` grant; no table grants to `anon`. `branch_keywords`: `select` for Super Admin (all rows) and Business Admin (rows of branches in their company); no insert/update/delete grant for any role; nothing for `anon`. Customers: RPC only (`security definer`, fixed `search_path`).
- Branch keyword writes go only through `set_branch_keywords(p_branch_id, p_keyword_ids)`: `security definer`, fixed `search_path`, execute granted to `authenticated` only. The role is checked server-side: Super Admin, or Business Admin whose company owns the branch; otherwise `42501 forbidden`. Unknown branch → `P0002`. Null means no picks; duplicate ids are merged; more than 10 distinct ids → `22023 too many keywords`; any id that is not an active keyword → `22023 unknown keyword`. The branch's rows are replaced in one transaction with positions 1..n.
- Role/company are read from `profiles`, never from client input or JWT claims the user can edit.
- Service-role key only in the Edge Function, never in the frontend.
- Server-side validation in `submit_feedback`: rating 1-5; text length caps (comment 2000, contact 200); at most 10 distinct keyword ids (duplicates merged); every keyword id must be an active keyword picked for that branch (`22023 unknown keyword`, replacing the old answer validation); reject inactive branches.
- Abuse: simple flood control of 30 submissions per branch per client address per 10 minutes (`54000`). No CAPTCHA in v1 (section 11, item 4). Render all user text as plain text (no HTML).
- Customer data is personal data if contact is given; keep contact optional and visible only to that company.

## 7. Performance

Form load under 1.5s on mobile: one RPC call, small JS bundle for the `/f/` route (lazy-load admin code), no auth round-trip. Caching beyond this only if measured to be needed.

## 8. Out of scope (v1)

AI keyword selection or rephrasing, per-company private keyword libraries, keyword bulk import, keyword SEO rank or usage reports, email/SMS alerts, customer accounts, auto-posting to Google, Business Admin editing the taxonomy, the keyword library or branch details, deleting taxonomy items or keywords (archive only), reordering keywords in the UI (sort order is set on create), non-English labels.

## 9. Acceptance criteria

1. Opening `/f/{slug}` of an active branch renders that branch's active picked keywords, in picked order (at most 10), with category and company names; a branch with no picks shows no chips. Unknown or inactive slug, and an archived subcategory or category, show not-found.
2. A valid submission is stored with the correct branch/company and `{id,label}` keyword snapshots; invalid payloads (rating 0 or 6, a keyword not picked for that branch, an archived keyword, more than 10 keyword ids, oversized text) are rejected.
3. Thank-you screen shows the Google link for ratings 1-5; for < 4 it also shows the manager card at equal prominence.
4. Business Admin A cannot read, update or delete company B's submissions or branches, even by calling Supabase directly (denied-path tests). Business Admin cannot write categories, subcategories or keywords, and cannot set the keywords of another company's branch (`42501`). Business Admin can set the keywords of their own company's branches.
5. Anonymous users cannot `select` from any table.
6. An archived keyword does not appear on the customer form or in the pickers, except dimmed in a branch's list when it is already picked. An archived subcategory or category makes its form not-found. Archived categories, subcategories and keywords stay visible (dimmed) in the Super Admin screens.
7. Super Admin can create a category, subcategory, keyword (in the library), company (Category then Subcategory), branch and Business Admin login, set up to 10 keywords for a branch, and download the QR.
8. Form is usable on iOS Safari and Android Chrome; load under 1.5s on a throttled mobile profile.

## 10. Testing plan

Run against a real Supabase project (or local `supabase start`): RLS allow/deny matrix per role and table (`supabase/tests/rls.sql`, including keyword library seed counts, `set_branch_keywords` rules and the submit keyword cap), RPC validation cases, an end-to-end customer flow in a browser at a mobile viewport, and a Lighthouse/throttled load check.

## 11. Open questions (defaults assumed, please confirm)

1. **Private "tell the manager" option:** I assumed every low-rating submission is already visible to the manager, so the card is an acknowledgement, with an optional contact field on the form. If you want a separate extra step, say so.
2. **Slug:** a short random slug, not the raw database UUID in the URL. App domain is TBD.
3. **Auth method:** email + password through Supabase Auth, Super Admin seeded manually.
4. **Spam control:** simple rate limit only. No CAPTCHA in v1.
5. **Languages:** English only in v1. Confirm that the client does not need local languages on the customer form.
6. **Data retention:** keep all submissions indefinitely.
