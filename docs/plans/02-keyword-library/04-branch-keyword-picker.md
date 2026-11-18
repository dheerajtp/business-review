# 02/04 — Branch keyword picker, branch screens, Business Admin page

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: 02/02 · Parallel with: 02/03 (disjoint files). Shared files: `App.jsx` and `Sidebar.jsx` are owned by 02/02; make only the two small named edits below.

## Decisions you need
K3 (branch_keywords read access), K4 (RPC errors), K10 (picker UI) — run `grep -E '^\| (K3|K4|K10) ' 00-README.md`.

## Read first
- `web/src/admin/BranchForm.jsx` and `CompanyDetailPage.jsx` (where branches are listed/edited; the company's `subcategories(category_id, categories(name))` join).
- `web/src/App.jsx` (route groups, lazy imports) and `web/src/layout/Sidebar.jsx` (Business Admin nav array).
- `web/src/admin/KeywordsPage.jsx` (from 02/02: library query shape), `web/src/lib/db.js`, `web/src/ui/*`, `web/src/auth/AuthContext.js` (how to read the company id for Business Admin).

## Scope (files you own)
`web/src/shared/BranchKeywordsPicker.jsx` (new), `web/src/admin/BranchForm.jsx`, `web/src/admin/CompanyDetailPage.jsx`, `web/src/business/KeywordsPage.jsx` (new), appended `bkw-` block in `web/src/styles.css`, plus two edits: one lazy route `/business/keywords` in `web/src/App.jsx` (Business Admin group) and one Business Admin item "Keywords" in `web/src/layout/Sidebar.jsx`.

## Tasks
1. **Picker (K10).** Props: `branchId`, `categoryId` (may be null), `onSaved`. Loads active `keywords` (with `categories(name)`) and the branch's current picks from `branch_keywords` ordered by `position` (selected archived keywords still shown dimmed "archived"). Searchable checklist, default filter category + General with "Show all" toggle, counter `n / 10`, unchecked disabled at 10, pick order = position (a newly checked item goes last). Save calls `supabase.rpc('set_branch_keywords', { p_branch_id, p_keyword_ids })` with ids in order; map errors per K10 (`too many keywords`, `unknown keyword`, code `42501`); show "Saved".
2. **Super Admin screens.** In the branch edit surface (`BranchForm` for existing branches; `CompanyDetailPage` as needed to pass `categoryId`) add a "Review keywords" section using the picker. A new branch has no id yet: show "Save the branch first, then choose its keywords." until created.
3. **Business Admin page (K10).** `business/KeywordsPage.jsx`: lists the company's branches (RLS already limits) as collapsible cards, each with the picker (company category from `companies.subcategories.category_id`). Empty state when no branches. Route `/business/keywords`; sidebar item "Keywords" in the Business Admin nav.
4. **No direct writes.** Never insert/update/delete `branch_keywords` from the client.

## Done when
- `cd web && npm run build` passes; `grep -rn "branch_keywords" web/src` shows only `.select`/`from(...).select` reads and the `set_branch_keywords` rpc call.
- Manual checks (pick 10, 11th disabled, Business Admin edits own branch) need a database: report NOT RUN if unavailable.
- Append `## Result`.

## Result
Files: web/src/shared/BranchKeywordsPicker.jsx (new), web/src/business/KeywordsPage.jsx (new), web/src/admin/BranchForm.jsx (picker section, new `categoryId` prop), web/src/admin/CompanyDetailPage.jsx (selects `subcategories.category_id`, passes it), web/src/App.jsx (lazy route /business/keywords), web/src/layout/Sidebar.jsx (Business "Set up > Keywords"), web/src/styles.css (appended bkw- block).
Checks: `cd web && npm run build` PASS; grep branch_keywords shows only one .select and the comment; rpc call is the only write.
Manual checks (pick 10, 11th disabled, Business Admin edits own branch): NOT RUN (no database).
Notes: Business page reads company category from `companies` (RLS limits to own company). Selected keywords not in the active list render dimmed with an "archived" pill (label falls back to "Unavailable keyword" if RLS hides the row).
