# 03/02 — Company form, Categories pill, SPEC line, acceptance evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 03/01 (disjoint files)

## Decisions you need
P3 (company form), P4 (Categories page pill), P6 (out of scope) — run `grep -E '^\| (P3|P4|P6) ' 00-README.md`.

## Read first
- `web/src/admin/CompanyForm.jsx`: `categories`/`subcategories` props, `current`, the category select (`categories.filter(...)`), `subOptions`, the Subcategory `Field` and its `hint`.
- `web/src/admin/CompaniesPage.jsx`: where `categories` and `subcategories` are fetched and passed to the form (the subcategories query already returns `is_active` and `category_id`).
- `web/src/admin/CategoriesPage.jsx`: how categories and the selected category's subcategories are loaded and rendered (the list row markup for a category).
- `SPEC.md` section 5 (company create/edit line).

## Scope (files you own)
`web/src/admin/CompanyForm.jsx`, `web/src/admin/CompaniesPage.jsx`, `web/src/admin/CategoriesPage.jsx`, an appended `pc-` block in `web/src/styles.css`, `SPEC.md`, `docs/plans/03-prune-empty-categories/RESULT.md` (new).

## Tasks
1. **Company form (P3).** Compute `usableCategories` = categories that are active and have at least one active subcategory, plus the company's current category when editing. The category select uses only these. Change the Subcategory hint to "Pick the type of business." When `usableCategories` is empty, replace the selects with the message "Create a category with at least one subcategory first." and a `Link` to `/admin/categories`, and keep Save disabled. Default the initial category to the first usable one for a new company.
2. **Categories page (P4).** Show a small pill "No subcategories" on a category row when it has no active subcategories. This needs all subcategories, not just the selected category's: if the page only loads the selected category's, add one query for `subcategories(category_id, is_active)` and derive a set of category ids with active subcategories. Use `pc-` class names appended to `styles.css`; no delete UI.
3. **SPEC.md.** In the company create/edit line of section 5, add that only categories with at least one active subcategory are offered, and one sentence under the data model or flow that categories without subcategories are not assignable to companies.
4. **RESULT.md.** One row per acceptance checkbox in `00-README.md`: verified or "not verified (needs DB/browser)" with evidence and exact manual steps (apply the migration, open New company, pick a category, edit a company, open Categories). Only build and grep facts may be marked verified. Do not tick Status boxes for this slice.

## Done when
- `cd web && npm run build` passes; the Subcategory hint text no longer contains "keywords".
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
Changed: `web/src/admin/CompanyForm.jsx` (usableCategories, new hint, empty message with Link, Save disabled, default first category on new), `web/src/admin/CategoriesPage.jsx` (all-subcategories query, `badge` prop on Level, "No subcategories" pill, reloads on subcategory save/toggle), `web/src/styles.css` (`pc-empty`), `SPEC.md`, `RESULT.md` (new). `CompaniesPage.jsx` needed no change (already passes categories and subcategories with is_active). `cd web && npm run build` PASS. DB/browser checks not run; see RESULT.md.
