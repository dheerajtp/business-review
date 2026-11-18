# 02 — Global SEO keyword library and per-branch keyword selection

Master plan: none (repo has no `docs/PLAN.md`; `SPEC.md` is updated in slice 05) · Builds on: [`../01-category-subcategory/00-README.md`](../01-category-subcategory/00-README.md) (amends C2 keywords, C5, C6, C7, C8, C9)

## Goal
- Super Admin manages one **global keyword library** (SEO phrases) on a dedicated `/admin/keywords` page: seeded by default, can create, edit, archive.
- Each **branch** opts for at most **10** keywords from the library. Super Admin picks them; the company's Business Admin can change them later for their own branches.
- Customers see only the branch's keywords on the feedback form; the review draft is built from the ones they tap, to produce keyword-rich Google reviews.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| K1 | **Library schema.** New migration `supabase/migrations/20261118000001_keyword_library.sql` (never edit earlier migrations). `keywords` becomes global: delete all existing keyword rows (plan 01 seed), drop `subcategory_id` and its indexes, widen `label` to 1–60 chars, add `category_id uuid null references categories(id)` (null = General), `unique (lower(label))`, index on `(category_id, is_active)`. Keep `sort_order`, `is_active`, `created_at`. `feedback_submissions.keywords` snapshots are untouched. No hard delete. |
| K2 | **Seed (idempotent, `on conflict do nothing`).** ~12 General phrases + 6–8 phrases per category (8 categories from plan 01 C4), natural search phrases, lower case, ≤ 60 chars, e.g. General: `friendly staff`, `value for money`, `clean and hygienic`, `highly recommended`, `great customer service`; Restaurants & Cafes: `best coffee in town`, `family friendly restaurant`, `tasty food`, `cozy ambience`. Written fully in the migration; user reviews them in the diff. |
| K3 | **Branch selection table.** `branch_keywords(branch_id uuid → branches, keyword_id uuid → keywords, position int not null, primary key (branch_id, keyword_id), unique (branch_id, position))`, `position` 1..10. RLS on; `select` for `super_admin` (all) and `business_admin` (rows of branches where `company_id = current_company_id()`); **no** insert/update/delete grants and none for `anon`. Writes happen only through K4. |
| K4 | **Write RPC.** `set_branch_keywords(p_branch_id uuid, p_keyword_ids uuid[]) returns void`, security definer, `set search_path = public`, `revoke all from public`, grant execute to `authenticated` only. Rules: role must be `super_admin`, or `business_admin` with `branches.company_id = current_company_id()`, else `raise exception 'forbidden' using errcode = '42501'`; branch not found → `P0002`; null = empty; duplicates merged keeping first position; more than 10 distinct → `22023 'too many keywords'`; every id must be an existing **active** keyword, else `22023 'unknown keyword'`; replaces the branch's rows atomically (delete then insert with positions 1..n). |
| K5 | **Library permissions.** Keep plan 01 policies on `keywords`: `select` for any role with a profile, `insert/update` only `super_admin`, no `delete`. Archiving a keyword does not delete `branch_keywords` rows; archived keywords are hidden from the form and from pickers (except shown dimmed as "archived" if already selected). |
| K6 | **Form RPC.** `get_feedback_form(p_slug)` keeps all current fields; `keywords` becomes the branch's active picked keywords from `branch_keywords` ordered by `position`, `[{id,label}]`, max 10. No picks = empty list (no fallback). Not-found rules unchanged (inactive branch/company/subcategory/category). |
| K7 | **Submit RPC.** `submit_feedback(p_slug, p_rating, p_keyword_ids uuid[], p_comment, p_contact)` keeps its signature. Keywords must be active and picked for **that branch**, else `22023 'unknown keyword'`; the cap becomes 10 distinct (`22023 'too many keywords'`). Snapshot shape `[{id,label}]` unchanged. Flood control and other errors unchanged. |
| K8 | **Customer UI (amends plan 01 C8).** Questions are gone, so the branch's keyword selection is the main step of the branch review page `/f/{slug}`: stars, then the keyword chips directly below, then the editable review text, then contact (rating < 4 only, as today). Chips show for **every** rating (hidden only when the branch has none). Tap limit `MAX_KEYWORDS = 10`; selection persists when the rating changes. `composeReview`: no labels → rating ≥ 4 `Great experience at {company}!`, rating < 4 `My visit to {company} could have been better.`; with labels → rating ≥ 4 `Great experience at {company}! Recommended for {a}, {b} and {c}.`, rating < 4 `My visit to {company} could have been better, especially regarding {a}, {b} and {c}.` (join: 1 → `a`, 2 → `a and b`, 3+ → `a, b and c`; labels used as stored, no case changes). Draft stays editable and re-composes until the customer edits it. Google button/copy unchanged and equal for every rating. |
| K9 | **Admin Keywords page.** Route `/admin/keywords`, Super Admin only, sidebar entry "Keywords" under Set up. Table: label, category (or General), status. Search box, filter (All / General / each category / Archived), add and edit modal (`label` ≤ 60, optional category), archive/restore, new rows `sort_order = max+1`. Unique violation shows "That keyword already exists." The Categories page drops its keywords section and shows categories and subcategories only. |
| K10 | **Branch picking UI.** One shared component `web/src/shared/BranchKeywordsPicker.jsx`: searchable checklist of active keywords, default filter = the company's category + General with a "Show all" toggle, counter `n / 10`, unchecked items disabled at 10, pick order = position, Save calls `set_branch_keywords` and shows "Saved" or the mapped error ("You can choose up to 10 keywords." for `too many keywords`, "That keyword is no longer available." for `unknown keyword`, "You can't change this branch." for `42501`). Used in (a) Super Admin branch screens (branch edit in `BranchForm`/`CompanyDetailPage`) and (b) Business Admin page `/business/keywords` listing their company's branches, each with the picker; sidebar entry "Keywords" for Business Admin. |
| K11 | **Removed.** Per-subcategory keyword management and every use of `keywords.subcategory_id`; the plan 01 "Review categories and keywords" wording becomes "Review categories and the keyword library" in `GetStarted.jsx`. |
| K12 | **Tests.** `supabase/tests/rls.sql` updated: library seed counts (every category ≥ 6, General ≥ 10), library write allowed for super admin and denied for business admin and anon, `set_branch_keywords` (super ok; business admin own branch ok; other company `42501`; 11 ids rejected; archived/unknown rejected; replace and ordering; duplicates merged), `branch_keywords` has no direct writes for any role and anon sees nothing, form RPC returns picked order and only active, submit rejects a keyword not picked for that branch and accepts picked ones, `submit` with 11 ids rejected. |
| K13 | **Out of scope (later).** SEO rank/analytics tracking, AI-generated keywords, per-company private libraries, keyword bulk import, a per-keyword usage report. |

## Status
- [x] 01 — Schema, seed, RPCs, RLS tests (static review only; DB tests NOT RUN, user applies migration)
- [x] 02 — Admin Keywords page, Categories trim, nav (manual checks NOT RUN; `.tax-grid` still 3 columns)
- [x] 03 — Branch review page: keyword selection in place of questions, review text, 10 cap (gated while 02 in flight; manual checks NOT RUN; chips appear after the first star tap)
- [x] 04 — Branch keyword picker, Super Admin branch screens, Business Admin page (manual checks NOT RUN)
- [x] 05 — Acceptance: SPEC.md, plan 01 amendment notes, checklist evidence

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | none (schema never parallel) | Opus (security-definer RPC + RLS) | `supabase/migrations/20261118000001_keyword_library.sql`, `supabase/tests/rls.sql` |
| 02 | 01 | 03 | Sonnet | `web/src/admin/KeywordsPage.jsx` (new), `web/src/admin/KeywordForm.jsx`, `web/src/admin/CategoriesPage.jsx`, `web/src/admin/GetStarted.jsx`, `web/src/App.jsx`, `web/src/layout/Sidebar.jsx`, `web/src/layout/NavIcon.jsx` |
| 03 | 01 | 02 | Sonnet | `web/src/customer/**`, `web/src/lib/types.js` |
| 04 | 02 | 03 | Sonnet | `web/src/shared/BranchKeywordsPicker.jsx` (new), `web/src/admin/BranchForm.jsx`, `web/src/admin/CompanyDetailPage.jsx`, `web/src/business/KeywordsPage.jsx` (new), `web/src/App.jsx` (one added route), `web/src/layout/Sidebar.jsx` (one added Business item), `web/src/styles.css` (appended `bkw-` block) |
| 05 | 03, 04 | none | Haiku | `SPEC.md`, `docs/plans/02-keyword-library/RESULT.md`, `docs/plans/01-category-subcategory/00-README.md` (one-line note) |

02 and 03 touch disjoint files. 04 waits for 02 because both edit `App.jsx` and `Sidebar.jsx`: 02 owns them, and 04 makes only the small named edits listed above (one lazy route `/business/keywords`, one Business sidebar item). 02 appends no CSS beyond a `kwl-` block; 04 appends a `bkw-` block; keep the blocks separate.

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; `cd web && npm run build` must pass for web slices; SQL is written and statically reviewed only unless a local database exists (the user applies migrations); never touch a remote Supabase project; append `## Result` to the slice file.

## Acceptance checklist
- [ ] After the migration, the library has General ≥ 10 and every category ≥ 6 seeded keywords; `rls.sql` prints `ALL RLS TESTS PASSED`.
- [ ] `/admin/keywords` lets Super Admin search, filter, create, edit and archive/restore keywords; duplicates are refused; Business Admin cannot open it or write keywords.
- [x] Categories page shows only categories and subcategories.
- [ ] Super Admin can pick up to 10 keywords for a branch; the 11th is not selectable and the RPC rejects it.
- [ ] A Business Admin can change keywords on their own company's branches at `/business/keywords` and cannot change another company's branch.
- [ ] `/f/{slug}` shows only that branch's active picked keywords, in picked order, for every rating, directly under the stars; none picked shows no chips.
- [ ] Tapping keywords composes the K8 review text; a manual edit sticks; copy and Google button work at equal prominence for every rating.
- [ ] Submit rejects a keyword not picked for the branch, an archived one, and more than 10; valid submit stores `{id,label}` snapshots; feedback lists still show chips.
- [x] `SPEC.md` describes the keyword library and per-branch selection.
