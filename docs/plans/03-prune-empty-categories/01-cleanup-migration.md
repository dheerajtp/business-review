# 03/01 — Cleanup migration and test

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 03/02 (disjoint files)

## Decisions you need
P1 (cleanup statements), P2 (safety and header comment), P5 (test) — run `grep -E '^\| (P1|P2|P5) ' 00-README.md`.

## Read first
- `supabase/migrations/20261118000001_keyword_library.sql`: the `keywords.category_id` column and its foreign key to `categories`.
- `supabase/migrations/20261117000001_taxonomy.sql`: `subcategories.category_id` (FK to `categories`) and how `categories` is defined.
- `supabase/tests/rls.sql`: the seed section at the top (temp table `_ids`, `do $$ ... assert` style) and the section order, to place the new section right after the seed section.

## Scope (files you own)
- `supabase/migrations/20261119000001_prune_empty_categories.sql` (new)
- `supabase/tests/rls.sql`

## Tasks
1. **Migration (P1, P2).** Header comment: what it deletes (categories with no subcategory rows, active or archived), that keywords of those categories become General, and the preview query from P2. Then exactly the two statements from P1, in that order. Check there is no other table with a foreign key to `categories` (search all migrations for `references public.categories`); if there is one besides `subcategories` and `keywords`, handle it and say so in Result.
2. **Test (P5).** In `rls.sql`, add a section after the seed section: insert category `Empty cat`, a keyword `empty cat keyword` with that `category_id`; run the two P1 statements verbatim; assert the category is gone, the keyword exists with `category_id is null`, and `count(*)` of categories = 8 and subcategories = 29 (same numbers the seed section asserts). Delete the test keyword at the end so later sections' counts are unchanged. Make sure later sections that count keywords or categories still pass.

## Done when
- Static review passes: statement order, FK handling, no later `rls.sql` assertion changes (no database here; report DB checks NOT RUN; the user applies the migration).
- Append `## Result`.

## Result
- Added `supabase/migrations/20261119000001_prune_empty_categories.sql` (header + the two P1 statements in order: keywords to General, then delete empty categories).
- Added a section to `supabase/tests/rls.sql` right after the seed re-run check (before the fixtures); it deletes its test keyword at the end, so later counts are unchanged.
- FK check: only `subcategories` and `keywords` reference `categories` now (`companies.category_id` and `questions` were dropped in the taxonomy migration), so nothing else is handled.
- Checks: static review only; DB run NOT RUN (no database here). Later fixture categories (Cafe, Boutique) are inserted after the section, so they are unaffected.
