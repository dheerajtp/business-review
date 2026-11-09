# Fairobuy: NFC Feedback Platform, v1 Spec

Status: DRAFT, awaiting approval. Repository is empty; stack is `react-supabase` (STACK_CONFIG.md). No custom Node backend.

## 1. Objective

Customers tap an NFC card or scan a QR code at a branch, rate it 1-5, answer admin-defined questions, and are offered the branch's Google review link. Ratings below 4 are also shown to the company as complaints. Goal: more Google reviews per branch while giving managers a private feedback channel.

Built for one client (a group of 5-30 branches across several business types), implemented multi-tenant.

## 2. Roles

| Role | Can do |
|---|---|
| Super Admin | CRUD categories, category questions, companies, branches (incl. Google Place ID), Business Admin accounts; review question requests; view all feedback |
| Business Admin | One company. View that company's branches and feedback only (filter by branch, rating < 4, 1-2 star highlighted). Submit company-specific question requests. Read-only on questions and branch details |
| Customer | No login. Open `/f/{slug}`, submit feedback |

## 3. Data model (additive, new project)

- `categories`: id, name, description, is_active, created_at
- `companies`: id, name, category_id, is_active, created_at (one category per company)
- `branches`: id, company_id, name, slug (unique, random, non-guessable), google_place_id, is_active
- `profiles`: user_id (= auth.users.id), role (`super_admin` | `business_admin`), company_id (null for super admin)
- `questions`: id, category_id, company_id (**null = whole category, set = that company only**), text, type (`single` | `multi` | `scale` | `text`), options (jsonb, for single/multi), is_required, sort_order, is_active
- `question_requests`: id, company_id, requested_by, text, status (`pending` | `approved` | `rejected`), reviewed_by, created_at
- `feedback_submissions`: id, branch_id, company_id (denormalised for RLS), rating (1-5), answers (jsonb; stores question text + type snapshot with each answer), comment, contact (optional), clicked_google (bool), created_at

Indexes: `feedback_submissions(company_id, created_at desc)`, `(branch_id, created_at desc)`, `(company_id, rating)`; `branches(slug)`; `questions(category_id, is_active)`.

## 4. Customer flow (`/f/{slug}`, anonymous, mobile-first)

1. Page calls one RPC `get_feedback_form(slug)` returning branch name, Google Place ID and the ordered active questions (category questions + that company's own). Inactive branch/company returns not-found.
2. Customer picks 1-5 stars (mandatory), answers questions, optional comment. If rating < 4, an optional contact field (phone or email) is shown.
3. Submit calls RPC `submit_feedback(slug, rating, answers, comment, contact)`; the server validates everything and returns the submission id. Anonymous users have no direct table access.
4. Thank-you screen, **same for every rating**:
   - "Post on Google" button → `https://search.google.com/local/writereview?placeid=<PLACE_ID>`, plus a one-tap "Copy my comment".
   - Rating < 4: a card **side by side with equal visual weight** saying the feedback has gone to the manager. The Google button is never hidden or demoted.
5. Google button tap calls RPC `mark_google_click(submission_id)`, which sets `clicked_google` (best-effort, never blocks the redirect).

Google policy: no gating. Every rating sees the Google link at the same prominence.

## 5. Admin features

**Super Admin**
- Category CRUD with archive (`is_active=false`, no hard delete).
- Question setup screen: pick a category, add/edit/reorder/disable questions (4 types), live phone-frame preview of the customer form. Soft limit of about 5 questions per form, shown as a warning (not enforced).
- Company and branch CRUD. Branch screen shows the NFC URL `https://<app-domain>/f/{slug}` (for writing to the tag) and a downloadable QR code.
- Create Business Admin logins (Edge Function, since this needs the service-role key).
- Question requests inbox: approve (creates a company-scoped question, editable before saving) or reject.

**Business Admin**
- Dashboard: submissions list with branch filter, rating filter, date range, "needs attention" view (< 4 stars, 1-2 highlighted). Basic counts and average rating per branch.
- "Request a question" form and the status of their requests.

## 6. Security

- RLS on every table. Business Admin: `company_id = (select company_id from profiles where user_id = auth.uid())`. Super Admin: role check via the same `profiles` row. Customers: RPC only (`security definer`, fixed `search_path`), no table grants to `anon`.
- Role/company are read from `profiles`, never from client input or JWT claims the user can edit.
- Service-role key only in the Edge Function, never in the frontend.
- Server-side validation in `submit_feedback`: rating 1-5; answers match the active question ids for that branch; option values valid; text length caps (comment, answers, contact); reject inactive branches.
- Abuse: basic per-IP/branch rate limit (open question 4). Render all user text as plain text (no HTML).
- Customer data is personal data if contact is given; keep contact optional and visible only to that company.

## 7. Performance

Form load under 1.5s on mobile: one RPC call, small JS bundle for the `/f/` route (lazy-load admin code), no auth round-trip. Caching beyond this only if measured to be needed.

## 8. Out of scope (v1)

AI question selection/rephrasing, email/SMS alerts, per-branch question overrides, customer accounts, auto-posting to Google, Business Admin editing questions or branch details.

## 9. Acceptance criteria

1. Opening `/f/{slug}` of an active branch renders the correct category + company questions; unknown/inactive slug shows not-found.
2. A valid submission is stored with the correct branch/company; invalid payloads (rating 0 or 6, unknown question id, oversized text) are rejected.
3. Thank-you screen shows the Google link for ratings 1-5; for < 4 it also shows the manager card at equal prominence.
4. Business Admin A cannot read, update or delete company B's submissions, branches or requests, even by calling Supabase directly (denied-path tests).
5. Anonymous users cannot `select` from any table.
6. Approved company question appears only on that company's forms, after the category questions.
7. Super Admin can create category, questions, company, branch, Business Admin login, and download the QR.
8. Form is usable on iOS Safari and Android Chrome; load under 1.5s on a throttled mobile profile.

## 10. Testing plan

Run against a real Supabase project (or local `supabase start`): RLS allow/deny matrix per role and table, RPC validation cases, an end-to-end customer flow in a browser at a mobile viewport, and a Lighthouse/throttled load check.

## 11. Open questions (defaults assumed, please confirm)

1. **Private "tell the manager" option:** I assumed every low-rating submission is already visible to the manager, so the card is an acknowledgement, with an optional contact field on the form. If you want a separate extra step, say so.
2. **Slug:** a short random slug, not the raw database UUID in the URL. App domain is TBD.
3. **Auth method:** email + password through Supabase Auth, Super Admin seeded manually.
4. **Spam control:** simple rate limit only. No CAPTCHA in v1.
5. **Languages:** English only in v1. Confirm that the client does not need local languages on the customer form.
6. **Data retention:** keep all submissions indefinitely.

Implementation has NOT started. Waiting for your approval.
