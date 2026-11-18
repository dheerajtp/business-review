# 02/02 — Admin Keywords page, Categories trim, nav

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: 02/01 · Parallel with: 02/03 (disjoint files)

## Decisions you need
K1 (library columns), K5 (permissions), K9 (page), K11 (removed) — run `grep -E '^\| (K1|K5|K9|K11) ' 00-README.md`.

## Read first
- `web/src/admin/CategoriesPage.jsx` (the third keywords section and its state), `KeywordForm.jsx` (currently subcategory-scoped), `SubcategoryForm.jsx` (modal pattern), `saveError.js`.
- `web/src/admin/GetStarted.jsx` (step key `keywords`), `web/src/App.jsx` (lazy routes), `web/src/layout/Sidebar.jsx` (nav arrays), `NavIcon.jsx` (icon map).
- `web/src/lib/db.js`, `web/src/ui/{Modal,Field,EmptyState,ErrorState,PageHead}.jsx`, `web/src/lib/useAsync.js`.

## Scope (files you own)
`web/src/admin/KeywordsPage.jsx` (new), `web/src/admin/KeywordForm.jsx`, `web/src/admin/CategoriesPage.jsx`, `web/src/admin/GetStarted.jsx`, `web/src/App.jsx`, `web/src/layout/Sidebar.jsx`, `web/src/layout/NavIcon.jsx`, and an appended `kwl-` block in `web/src/styles.css`.

## Tasks
1. **KeywordsPage (K9).** Query `keywords` with `categories(name)`; list with search (client-side, case-insensitive), filter select (All / General / each category / Archived), and per-row Edit and Archive/Restore. Archived rows dimmed. "New keyword" opens `KeywordForm`.
2. **KeywordForm.** Rewrite: fields `label` (required, `maxLength` 60) and `category` select (option "General" = null). Insert with `sort_order = max(existing)+1` (pass `nextOrder` from the page); update on edit. Map unique violations with `saveError.js` to "That keyword already exists." (add a message param if needed).
3. **Categories trim (K11).** Remove the keywords section/state/imports from `CategoriesPage`; it shows categories and subcategories only. Nothing may query `keywords.subcategory_id`.
4. **Nav.** Route `/admin/keywords` inside the Super Admin-only route group; sidebar item "Keywords" under Set up (reuse an existing icon key or add one to `NavIcon`). Update the Get Started step text to "Review categories and the keyword library" linking `/admin/keywords`.

## Done when
- `cd web && npm run build` passes; `grep -rn "subcategory_id" web/src/admin/Keyword*.jsx web/src/admin/CategoriesPage.jsx` has no keyword query.
- Manual checks (create, edit, archive, filter, duplicate error, Business Admin cannot open the route) need a database: report NOT RUN if unavailable.
- Append `## Result`.

## Result
Changed: KeywordsPage.jsx (new), KeywordForm.jsx (rewritten, local duplicate message since saveError.js is out of scope), CategoriesPage.jsx (keywords removed), GetStarted.jsx, App.jsx, Sidebar.jsx, NavIcon.jsx (`keywords` icon), styles.css (kwl- block).
Checks: `cd web && npm run build` PASS; grep for subcategory_id in Keyword*.jsx/CategoriesPage.jsx: none. Manual checks (create/edit/archive/filter/duplicate/role gate) NOT RUN (no database).
Note: `.tax-grid` is still 3 columns on wide screens (CSS outside scope); categories page now uses 2.
