# 01 — Category, subcategory and keywords (replaces questions)

Amended by plan 02: keywords are now a global library chosen per branch (see ../02-keyword-library/00-README.md).
Master plan: none (repo has no `docs/PLAN.md`; `SPEC.md` is the product spec and is updated in slice 04) · Builds on: `supabase/migrations/20261005000001_init.sql`, `SPEC.md`

## Goal
- Super Admin gets a seeded set of categories, each with subcategories, each with keywords, and can add/edit/archive all three levels.
- A company has one subcategory (its category follows from it). No more per-category or per-company questions.
- The customer form is: stars → tap keywords → editable review text composed from the keywords → Google. Keywords are stored on the submission.
- Existing data is wiped (companies, branches, feedback, Business Admin logins, questions, requests). Auth Super Admin accounts survive.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| C1 | **Reset.** New migration `supabase/migrations/20261117000001_taxonomy.sql` (never edit older migrations). In order: delete `feedback_submissions`, `branches`; delete `auth.users` rows whose profile role is `business_admin` (cascades their profiles); delete `companies`; drop `question_requests`, `questions`, function `questions_company_matches_category()`; drop `companies.category_id` and `feedback_submissions.answers`. Destructive: only applied by the user (`supabase db push`/`db reset`), and the slice must not run it against any remote project. Super Admin profiles are kept. |
| C2 | **Schema.** `categories` (existing) gains `unique (lower(name))` and `sort_order int not null default 0`.<br>`subcategories(id uuid pk, category_id uuid not null → categories, name text 1–80, sort_order int default 0, is_active bool default true, created_at)` with `unique (category_id, lower(name))`.<br>`keywords(id uuid pk, subcategory_id uuid not null → subcategories, label text 1–40, sort_order int default 0, is_active bool default true, created_at)` with `unique (subcategory_id, lower(label))`.<br>`companies.subcategory_id uuid not null → subcategories` (added after the C1 delete, so no backfill). Category is derived: `companies → subcategories → categories`.<br>`feedback_submissions.keywords jsonb not null default '[]'` = array of `{id,label}` snapshots (labels survive later edits). Indexes on `subcategories(category_id)`, `keywords(subcategory_id, is_active)`, `companies(subcategory_id)`. No hard delete anywhere: archive via `is_active=false`. |
| C3 | **RLS/grants.** Same pattern as categories today: `select` for any role with a profile (`current_app_role() is not null`); `insert/update` only `super_admin`; no `delete` grant; `anon` has no table grants. Applies to `subcategories` and `keywords`. |
| C4 | **Seed (idempotent, `on conflict do nothing`, in the same migration).** Categories → subcategories:<br>Restaurants & Cafes → Fine dining, Casual dining, Cafe, Fast food, Bakery & Desserts<br>Retail → Clothing & Fashion, Electronics, Grocery & Supermarket, Home & Furniture<br>Healthcare → Clinic, Hospital, Dental, Pharmacy, Diagnostics & Lab<br>Beauty & Wellness → Salon, Spa & Massage, Barbershop<br>Hotels & Stays → Hotel, Resort, Hostel & Guesthouse<br>Automotive → Showroom, Service Center, Car Wash<br>Education → School, Coaching Center, Training Institute<br>Fitness → Gym, Yoga & Studio, Sports Club |
| C5 | **Seed keywords.** 6–8 per subcategory, neutral aspect labels that read naturally after "the" or in a list, so they work for both good and bad ratings (e.g. Cafe: Coffee quality, Ambience, Staff, Service speed, Cleanliness, Value for money, Seating). The slice writes them all into the migration; the user reviews them in the diff. Labels ≤ 40 chars, no duplicates within a subcategory. |
| C6 | **Form RPC.** `get_feedback_form(p_slug)` keeps its security-definer/anon grant and returns `{branch_name, company_name, google_place_id, category_name, subcategory_name, keywords:[{id,label}]}`; keywords are active only, ordered by `sort_order, label`. Not-found rules unchanged, plus inactive subcategory or category = not found. |
| C7 | **Submit RPC.** `submit_feedback(p_slug text, p_rating int, p_keyword_ids uuid[], p_comment text, p_contact text) returns uuid` replaces the old signature (drop old, re-grant to anon/authenticated). Rules: rating 1–5 (`22023`); `p_keyword_ids` null = empty, max 8 distinct ids (`22023 'too many keywords'`); every id must be an active keyword of the branch company's subcategory, else `22023 'unknown keyword'`; comment ≤ 2000, contact ≤ 200 (existing checks); same unknown-branch (`P0002`) and flood control (30 / 10 min, `54000`) logic as today. Stores `keywords` as `[{id,label}]` ordered as submitted. `mark_google_click` unchanged. |
| C8 | **Review text.** Pure client function `composeReview({company, rating, labels})` in `web/src/customer/reviewText.js`. Rating ≥ 4: no labels → `Great experience at {company}!`; else `Great experience at {company}! I especially liked the {a}, {b} and {c}.` Rating < 4: no labels → `My visit to {company} could have been better.`; else `My visit to {company} could have been better, mainly the {a}, {b} and {c}.` List join: 1 → `a`; 2 → `a and b`; 3+ → `a, b and c`; labels lower-cased except when they contain an uppercase letter after the first character. The result prefills the existing comment textarea and is re-composed on rating/keyword change until the customer edits the textarea by hand. It is a draft the customer edits and copies; nothing is auto-posted, and the Google button keeps equal prominence for every rating (no gating). |
| C9 | **Admin UI.** `/admin/categories` becomes the taxonomy screen: category list; selecting a category shows its subcategories; selecting a subcategory shows its keywords. At each level: create, rename, archive/restore (no delete), and keyword add/reorder-free (sort_order set on create = max+1, edit by number not required). Archived items are hidden from company pickers and the customer form but shown (dimmed) here. Company form: Category select then Subcategory select (filtered to the category, both required, active only plus the company's current). Company list/detail show `Category › Subcategory`. |
| C10 | **Removed.** Pages and routes `/admin/questions`, `/admin/requests`, `/business/request`; components `QuestionsPage, QuestionForm, QuestionRow, RequestsPage, FormPreview, RequestQuestionPage, QuestionField`; sidebar entries and icons for them; `pendingRequests` in the notify provider/context, notification menu and sidebar badge; the "Add the questions" Get Started step (replaced by "Review categories and keywords"). Business Admin is read-only on feedback only. |
| C11 | **Feedback display.** `FeedbackListPage` selects `keywords` instead of `answers`; `SubmissionCard` shows keyword labels as chips (nothing when empty). `dashboard_stats`/`branch_stats` are unchanged. |
| C12 | **Tests.** `supabase/tests/rls.sql` is rewritten for the new schema, keeping every non-question section (anon cannot read tables, business admin isolation, inactive hiding, last_seen, list_business_admins, dashboard_stats, no-profile user). New checks: seed counts (8 categories, every subcategory has ≥ 6 active keywords), subcategory/keyword write allowed for super admin and denied for business admin and anon, submit with valid/foreign/archived/too-many/duplicate keyword ids, form RPC keyword list. |
| C13 | **Stack rules.** `react-supabase`: no new backend, RLS is the boundary, plain JS (no TypeScript), existing `useAsync`, `must`/`supabase` from `web/src/lib/db.js`, existing `Modal`/`Field`/`EmptyState`/`ErrorState` UI. |

## Status
- [x] 01 — Schema reset, seed, RPCs, RLS tests (static review only; DB tests NOT RUN, user applies migration)
- [x] 02 — Admin taxonomy UI, company form, remove question screens (manual checks NOT RUN)
- [x] 03 — Customer keyword form, review text, feedback display (gated while 02 in flight; manual checks NOT RUN)
- [x] 04 — Acceptance: SPEC.md update, runbook, checklist evidence (see RESULT.md; most rows need DB/browser)

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | none (schema never parallel) | Opus (destructive migration + RPC auth) | `supabase/migrations/20261117000001_taxonomy.sql`, `supabase/tests/rls.sql` |
| 02 | 01 | 03 | Sonnet | `web/src/admin/**`, `web/src/layout/**`, `web/src/notify/**`, `web/src/business/**`, `web/src/App.jsx` |
| 03 | 01 | 02 | Sonnet | `web/src/customer/**`, `web/src/shared/**`, `web/src/lib/types.js` |
| 04 | 02, 03 | none | Haiku | `SPEC.md`, `docs/plans/01-category-subcategory/RESULT.md` |

02 and 03 have disjoint globs. 02 must not import from `web/src/lib/types.js` (03 deletes its question constants); `EMPTY_DRAFT` becomes `{ rating: 0, keywordIds: [], comment: '', contact: '' }` in 03.

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; `cd web && npm run build` must pass for web slices; SQL slices verify with `supabase db reset` and `psql -f supabase/tests/rls.sql` against a **local** database only; never touch a remote Supabase project; append `## Result` to the slice file.

## Acceptance checklist
- [ ] After `supabase db reset`, 8 categories, the C4 subcategories and 6–8 keywords per subcategory exist; `rls.sql` prints `ALL RLS TESTS PASSED`.
- [ ] Super Admin can create, rename and archive a category, a subcategory and a keyword; Business Admin and anon cannot write them.
- [ ] Company form requires Category then Subcategory; list/detail show `Category › Subcategory`.
- [ ] Opening `/f/{slug}` shows the subcategory's active keywords; archived keywords/subcategory/category do not show (archived parent = not found).
- [ ] Selecting keywords and a rating fills an editable review text per C8; Copy and Google button work for every rating at equal prominence.
- [ ] Submit rejects a keyword from another subcategory, an archived one, and more than 8 ids; valid submit stores `{id,label}` snapshots.
- [ ] Feedback lists (Super Admin and Business Admin) show keyword chips; dashboard still loads.
- [x] No Questions, Requests or Request-a-question screens, nav items, badges or notifications remain; build has no dead imports.
- [x] `SPEC.md` describes the keyword model; no mention of questions as a feature.
