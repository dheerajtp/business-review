# 01/01 — Schema reset, seed, RPCs, RLS tests

Plan folder: [`00-README.md`](00-README.md) · Model: Opus · Prerequisites: none · Parallel with: none

## Decisions you need
C1 (reset), C2 (schema), C3 (RLS), C4 (seed categories), C5 (seed keywords), C6 (form RPC), C7 (submit RPC), C12 (tests) — run `grep -E '^\| (C1|C2|C3|C4|C5|C6|C7|C12) ' 00-README.md`.

## Read first
- `supabase/migrations/20261005000001_init.sql`: tables, `questions_company_matches_category`, RLS/grants block, `get_feedback_form`, `submit_feedback`, `mark_google_click`, grants at the end.
- `supabase/migrations/20261005000004_dashboard_stats.sql`: uses `companies`/`feedback_submissions` only; confirm nothing there references `category_id` or `answers`.
- `supabase/tests/rls.sql`: whole file (it is the test template; keep its style, `\echo` sections and fixtures approach).
- `supabase/tests/00_stubs.sql`: how auth is stubbed for the tests.

## Scope (files you own)
- `supabase/migrations/20261117000001_taxonomy.sql` (new)
- `supabase/tests/rls.sql`

## Tasks
1. **Reset (C1).** In the new migration, in the C1 order. Delete business-admin `auth.users` before `companies` (profiles reference companies). Drop `get_feedback_form(text)` and `submit_feedback(text,int,jsonb,text,text)` before recreating. Add a loud header comment that the migration is destructive.
2. **Schema (C2).** Create `subcategories`, `keywords`, the uniqueness and indexes, `categories.sort_order` and unique lower(name), `companies.subcategory_id not null`, `feedback_submissions.keywords`. Enable RLS on both new tables, revoke from anon/authenticated, then grant and policies per C3 (mirror `categories_read` / `categories_write`).
3. **Seed (C4, C5).** Insert categories, then subcategories (join by category name), then keywords (join by category+subcategory name) with explicit `sort_order`. Use `on conflict do nothing` on the unique indexes. Every subcategory in C4 gets 6–8 keywords, labels ≤ 40 chars.
4. **RPCs (C6, C7).** Recreate both as `security definer set search_path = public`, `revoke all ... from public`, grant execute to `anon, authenticated`. Keep flood control and error codes from the old `submit_feedback`. Validate keywords with one set-based query (distinct ids vs matching active keywords of `companies.subcategory_id`). Build the stored array in submitted order.
5. **Tests (C12).** Rewrite `rls.sql` fixtures to use categories/subcategories/keywords instead of questions; delete the question-request sections; add the new checks listed in C12. Keep all other sections working.

## Done when
- `supabase db reset` (local only) applies all migrations with no error; `psql -f supabase/tests/rls.sql` ends with `ALL RLS TESTS PASSED`.
- Seed counts match C4/C5; re-running the seed statements changes nothing.
- No reference to `questions`, `question_requests` or `answers` remains in `supabase/` except historic migrations.
- Append `## Result` (what ran, counts).

## Result

**Changed files**
- `supabase/migrations/20261117000001_taxonomy.sql` (new): destructive reset (C1), schema + RLS/grants (C2, C3), idempotent seed (C4, C5), recreated `get_feedback_form(text)` and `submit_feedback(text, int, uuid[], text, text)` (C6, C7).
- `supabase/tests/rls.sql`: rewritten fixtures (categories → subcategories → keywords), question/request sections removed, new C12 checks added; last_seen, list_business_admins, dashboard_stats and no-profile sections kept unchanged (no-profile also checks subcategories/keywords).

**Commands run**
- Static seed check (python parse of the migration's VALUES lists) → PASS: 8 categories, 29 subcategories, 205 keywords; every subcategory has 6–8 keywords, labels 1–40 chars, no case-insensitive duplicates per subcategory, sort_order 1..n, every keyword row joins to a seeded subcategory/category.
  Per category (subcategories/keywords): Restaurants & Cafes 5/36, Retail 4/28, Healthcare 5/35, Beauty & Wellness 3/21, Hotels & Stays 3/23, Automotive 3/20, Education 3/21, Fitness 3/21.
- `grep -rnE "questions|question_requests|answers" supabase/tests supabase/functions` → no matches. The new migration mentions them only in its drop statements/comments.
- `supabase db reset` → NOT RUN (no supabase CLI, psql or postgres here; the user applies the migration).
- `psql -f supabase/tests/rls.sql` → NOT RUN (same reason). Verified by reading the SQL only: statement order, FK dependencies, and that every table/function it references exists.

**Deviations and surprises**
- C1 order changed: `question_requests` and `questions` are dropped *before* the business-admin `auth.users` rows and `companies` are deleted. Following C1 literally would fail on foreign keys, because `question_requests.requested_by → auth.users` and `questions.company_id`/`question_requests.company_id → companies`. The old RPCs are dropped first too.
- Duplicate keyword ids in `submit_feedback` are merged into one, keeping the first-picked order (C7 says "max 8 distinct ids"). A null element counts as an `unknown keyword`. The validation order is: rating → text length → too many (>8 distinct) → unknown branch (P0002) → flood (54000) → unknown keyword.
- `categories_name_lower_key` (unique `lower(name)`) will fail on a live DB that already has categories whose names differ only by letter case. The user must check for this before applying.

**Facts for next slices**
- Form RPC returns `{branch_name, company_name, google_place_id, category_name, subcategory_name, keywords:[{id,label}]}`.
- Submit RPC args are `p_slug, p_rating, p_keyword_ids (uuid[]), p_comment, p_contact`. `feedback_submissions.keywords` holds the `[{id,label}]` array; `answers` is gone.
- `companies.subcategory_id` is required and `companies.category_id` is gone, so derive the category with `subcategories(category_id, categories(...))`.
- `categories.sort_order`, `subcategories.sort_order` and `keywords.sort_order` are ints with default 0. There is no delete grant on any taxonomy table (archive with `is_active`).
