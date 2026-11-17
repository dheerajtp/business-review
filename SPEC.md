# TapReview: NFC Feedback Platform, v1 Spec

Status: Implemented in plan `docs/plans/01-category-subcategory` (categories → subcategories → keywords replace questions). Migration `supabase/migrations/20261117000001_taxonomy.sql` is written but not yet applied by the owner; database tests (`supabase/tests/rls.sql`) and browser checks have not been run. See `docs/plans/01-category-subcategory/RESULT.md`. Stack is `react-supabase` (STACK_CONFIG.md). No custom Node backend.

## 1. Objective

Customers tap an NFC card or scan a QR code at a branch, rate it 1-5, tap the keywords that describe their visit, edit the review text that is drafted from them, and are offered the branch's Google review link. Ratings below 4 are also shown to the company as complaints. Goal: more Google reviews per branch while giving managers a private feedback channel.

Built for one client (a group of 5-30 branches across several business types), implemented multi-tenant.

## 2. Roles

| Role | Can do |
|---|---|
| Super Admin | Manage the taxonomy (categories, subcategories, keywords: create, rename, archive/restore); companies (category then subcategory), branches (incl. Google Place ID), Business Admin accounts; view all feedback |
| Business Admin | One company. View that company's branches and feedback only (filter by branch, rating < 4, 1-2 star highlighted). Read-only on feedback; cannot edit the taxonomy or company/branch setup |
| Customer | No login. Open `/f/{slug}`, submit feedback |

## 3. Data model (additive, new project)

- `categories`: id, name (unique, case-insensitive), description, sort_order, is_active, created_at
- `subcategories`: id, category_id → categories, name (1-80, unique per category, case-insensitive), sort_order, is_active, created_at
- `keywords`: id, subcategory_id → subcategories, label (1-40, unique per subcategory, case-insensitive), sort_order, is_active, created_at. Labels are neutral aspects ("Food quality", "Staff", "Cleanliness") that work for good and bad ratings
- `companies`: id, name, subcategory_id → subcategories (required), is_active, created_at. The category is derived: `companies → subcategories → categories`
- `branches`: id, company_id, name, slug (unique, random, non-guessable), google_place_id, is_active
- `profiles`: user_id (= auth.users.id), role (`super_admin` | `business_admin`), company_id (null for super admin)
- `feedback_submissions`: id, branch_id, company_id (denormalised for RLS), rating (1-5), keywords (jsonb array of `{id,label}` snapshots, in the order the customer picked them, so labels survive later edits), comment, contact (optional), clicked_google (bool), created_at

Seed (in the same migration, idempotent): 8 categories, 29 subcategories, 205 keywords (6-8 active keywords per subcategory). Categories: Restaurants & Cafes, Retail, Healthcare, Beauty & Wellness, Hotels & Stays, Automotive, Education, Fitness.

No hard delete anywhere: taxonomy rows are archived with `is_active = false`. Taxonomy tables have no `delete` grant.

Indexes: `feedback_submissions(company_id, created_at desc)`, `(branch_id, created_at desc)`, `(company_id, rating)`; `branches(slug)`; `subcategories(category_id)`; `keywords(subcategory_id, is_active)`; `companies(subcategory_id)`.

Removed: `questions`, `question_requests`, `companies.category_id`, `feedback_submissions.answers`. The migration wipes existing companies, branches, feedback and Business Admin logins; Super Admin accounts are kept.

## 4. Customer flow (`/f/{slug}`, anonymous, mobile-first)

1. Page calls one RPC `get_feedback_form(slug)` returning branch name, company name, Google Place ID, category name, subcategory name and the active keywords (`[{id,label}]`, ordered by `sort_order, label`). Inactive branch, company, subcategory or category returns not-found.
2. Customer picks 1-5 stars (mandatory), taps up to 8 keywords, and edits the review text. The review text is composed on the client from the company name, the rating and the chosen keywords (`web/src/customer/reviewText.js`). It prefills the comment box, is re-composed on rating or keyword change until the customer edits the text by hand, and is a draft the customer copies. Nothing is auto-posted. If rating < 4, an optional contact field (phone or email) is shown.
3. Submit calls RPC `submit_feedback(slug, rating, keyword_ids, comment, contact)`; the server validates everything and returns the submission id. Anonymous users have no direct table access.
4. Thank-you screen, **same for every rating**:
   - "Post on Google" button → `https://search.google.com/local/writereview?placeid=<PLACE_ID>`, plus a one-tap "Copy my comment".
   - Rating < 4: a card **side by side with equal visual weight** saying the feedback has gone to the manager. The Google button is never hidden or demoted.
5. Google button tap calls RPC `mark_google_click(submission_id)`, which sets `clicked_google` (best-effort, never blocks the redirect).

Google policy: no gating. Every rating sees the Google link at the same prominence.

## 5. Admin features

**Super Admin**
- Taxonomy screen at `/admin/categories`: category list; selecting a category shows its subcategories; selecting a subcategory shows its keywords. At each level: create, rename, archive/restore (no delete). Keywords are added with the next sort position. Archived items are shown dimmed here and hidden from company pickers and the customer form.
- Company create/edit: Category select, then Subcategory select filtered to that category (both required; active items, plus the company's current subcategory). Company list and detail show `Category › Subcategory`.
- Company and branch CRUD. Branch screen shows the NFC URL `https://<app-domain>/f/{slug}` (for writing to the tag) and a downloadable QR code.
- Create Business Admin logins (Edge Function, since this needs the service-role key).
- Feedback list with keyword chips per submission.

**Business Admin**
- Dashboard: submissions list with branch filter, rating filter, date range, "needs attention" view (< 4 stars, 1-2 highlighted), keyword chips per submission. Basic counts and average rating per branch.

## 6. Security

- RLS on every table. Business Admin: `company_id = (select company_id from profiles where user_id = auth.uid())`. Super Admin: role check via the same `profiles` row. Taxonomy tables: `select` for any role with a profile; `insert/update` only for Super Admin; no `delete` grant; no table grants to `anon`. Customers: RPC only (`security definer`, fixed `search_path`).
- Role/company are read from `profiles`, never from client input or JWT claims the user can edit.
- Service-role key only in the Edge Function, never in the frontend.
- Server-side validation in `submit_feedback`: rating 1-5; text length caps (comment 2000, contact 200); at most 8 distinct keyword ids (duplicates merged); every keyword id must be an active keyword of the branch company's subcategory (replaces the old answer validation); reject inactive branches.
- Abuse: simple flood control of 30 submissions per branch per client address per 10 minutes (`54000`). No CAPTCHA in v1 (section 11, item 4). Render all user text as plain text (no HTML).
- Customer data is personal data if contact is given; keep contact optional and visible only to that company.

## 7. Performance

Form load under 1.5s on mobile: one RPC call, small JS bundle for the `/f/` route (lazy-load admin code), no auth round-trip. Caching beyond this only if measured to be needed.

## 8. Out of scope (v1)

AI keyword selection or rephrasing, email/SMS alerts, per-branch keyword overrides, customer accounts, auto-posting to Google, Business Admin editing the taxonomy or branch details, deleting taxonomy items (archive only), reordering keywords in the UI (sort order is set on create), non-English labels.

## 9. Acceptance criteria

1. Opening `/f/{slug}` of an active branch renders the active keywords of its subcategory, with category and company names; unknown or inactive slug, and an archived subcategory or category, show not-found.
2. A valid submission is stored with the correct branch/company and `{id,label}` keyword snapshots; invalid payloads (rating 0 or 6, a keyword from another subcategory, an archived keyword, more than 8 keyword ids, oversized text) are rejected.
3. Thank-you screen shows the Google link for ratings 1-5; for < 4 it also shows the manager card at equal prominence.
4. Business Admin A cannot read, update or delete company B's submissions or branches, even by calling Supabase directly (denied-path tests). Business Admin cannot write categories, subcategories or keywords.
5. Anonymous users cannot `select` from any table.
6. An archived keyword does not appear on the customer form, and an archived subcategory or category makes its form not-found. Archived items stay visible (dimmed) in the Super Admin taxonomy screen.
7. Super Admin can create a category, subcategory, keyword, company (Category then Subcategory), branch and Business Admin login, and download the QR.
8. Form is usable on iOS Safari and Android Chrome; load under 1.5s on a throttled mobile profile.

## 10. Testing plan

Run against a real Supabase project (or local `supabase start`): RLS allow/deny matrix per role and table (`supabase/tests/rls.sql`), RPC validation cases, an end-to-end customer flow in a browser at a mobile viewport, and a Lighthouse/throttled load check.

## 11. Open questions (defaults assumed, please confirm)

1. **Private "tell the manager" option:** I assumed every low-rating submission is already visible to the manager, so the card is an acknowledgement, with an optional contact field on the form. If you want a separate extra step, say so.
2. **Slug:** a short random slug, not the raw database UUID in the URL. App domain is TBD.
3. **Auth method:** email + password through Supabase Auth, Super Admin seeded manually.
4. **Spam control:** simple rate limit only. No CAPTCHA in v1.
5. **Languages:** English only in v1. Confirm that the client does not need local languages on the customer form.
6. **Data retention:** keep all submissions indefinitely.
