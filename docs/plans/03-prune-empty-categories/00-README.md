# 03 — Remove categories without subcategories

Master plan: none (`SPEC.md` gets one line in slice 02) · Builds on: [`../01-category-subcategory/00-README.md`](../01-category-subcategory/00-README.md), [`../02-keyword-library/00-README.md`](../02-keyword-library/00-README.md)

## Goal
- A company needs a subcategory, so a category with none is unusable. Existing empty categories (e.g. a leftover "Cafe" that predates the seed) are removed.
- The company form never offers a category that has no active subcategory, so the dead end in the "New company" dialog cannot happen again.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| P1 | **One-off cleanup migration.** New `supabase/migrations/20261119000001_prune_empty_categories.sql` (never edit older migrations), in this order: (1) `update keywords set category_id = null` for keywords whose category has no subcategory rows (they become General, nothing is lost); (2) `delete from categories c where not exists (select 1 from subcategories s where s.category_id = c.id)`. "No subcategory" means no rows at all, active or archived. Idempotent, no schema change, no other tables touched (companies reference subcategories, so no company can point at a deleted category). |
| P2 | **Safety.** The migration only deletes rows that have no subcategories and, after P1, no keywords. Categories that have subcategories (all 8 seeded ones, any user-made ones with subcategories) are untouched. The user applies it; the header comment says which rows it removes and suggests `select name from categories c where not exists (select 1 from subcategories s where s.category_id = c.id);` to preview. |
| P3 | **Company form.** `CompanyForm` category select lists only categories that are active **and** have at least one active subcategory, plus the company's current category when editing (so an existing company never loses its value). The Subcategory hint text becomes "Pick the type of business." (the old "Decides which keywords customers can pick." is wrong since plan 02). If no category qualifies, the form shows "Create a category with at least one subcategory first." with a link to `/admin/categories`, and Save stays disabled. |
| P4 | **Categories page.** A category with no active subcategories shows a small pill "No subcategories" so the admin sees why it will not appear for companies. No deletion UI is added (archive stays the only in-app removal). |
| P5 | **Tests.** `supabase/tests/rls.sql` gains one section: insert a category `Empty cat` with no subcategories plus a keyword tagged to it, run the two P1 statements, assert the category is gone, the keyword still exists with `category_id is null`, and the 8 seeded categories and 29 subcategories are intact. |
| P6 | **Out of scope (later).** A database rule preventing categories without subcategories (an admin must be able to create a category first, then add subcategories), a delete button, bulk tools. |

## Status
- [x] 01 — Cleanup migration and test (static review only; DB tests NOT RUN, user applies migration)
- [x] 02 — Company form, Categories pill, SPEC line, acceptance evidence

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | 02 | Sonnet | `supabase/migrations/20261119000001_prune_empty_categories.sql` (new), `supabase/tests/rls.sql` |
| 02 | none | 01 | Sonnet | `web/src/admin/CompanyForm.jsx`, `web/src/admin/CompaniesPage.jsx`, `web/src/admin/CategoriesPage.jsx`, `web/src/styles.css` (appended `pc-` block), `SPEC.md`, `docs/plans/03-prune-empty-categories/RESULT.md` |

Disjoint files, so they run in parallel. This plan is small, so acceptance is folded into slice 02 instead of a separate slice.

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; `cd web && npm run build` must pass for web slices; SQL is written and statically reviewed only (the user applies migrations); never touch a remote Supabase project; append `## Result` to the slice file.

## Acceptance checklist
- [ ] After the migration, no category exists without a subcategory; keywords of removed categories still exist as General; seeded categories/subcategories are unchanged; `rls.sql` prints `ALL RLS TESTS PASSED`.
- [ ] The New company dialog lists only categories that have an active subcategory; picking one enables the Subcategory select with options; the hint text no longer mentions customer keyword picking.
- [ ] Editing a company whose category later became archived/empty still shows its current category.
- [ ] The Categories page marks a category with no active subcategories as "No subcategories".
- [x] `SPEC.md` states that only categories with subcategories can be assigned to companies.
