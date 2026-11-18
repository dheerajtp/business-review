# 04/02 — Company form picker, shared picker split, Business Admin page, SPEC, acceptance evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Sonnet · Prerequisites: none · Parallel with: 04/01 (disjoint files)

## Decisions you need
M2 (RPC name, args, errors), M7 (company form behaviour), M8 (picker split), M9 (Business Admin page and labels) — run `grep -E '^\| (M2|M7|M8|M9) ' 00-README.md`.

## Read first
- `web/src/shared/BranchKeywordsPicker.jsx`: the whole file; this is the checklist, load and save logic you will split.
- `web/src/admin/CompanyForm.jsx` (save flow, `categoryId`/`subcategoryId` state, usable categories), `CompaniesPage.jsx` (how the form is opened, `onSaved`), `CompanyDetailPage.jsx` and `BranchForm.jsx` (where the branch keyword section and its label live).
- `web/src/business/KeywordsPage.jsx`: the branch cards and how the company category is obtained.
- `web/src/lib/db.js`, `web/src/admin/saveError.js`.
- `SPEC.md` sections 2–5.

## Scope (files you own)
`web/src/shared/KeywordChecklist.jsx` (new), `web/src/shared/CompanyKeywordsPicker.jsx` (new), `web/src/shared/BranchKeywordsPicker.jsx`, `web/src/admin/CompanyForm.jsx`, `web/src/admin/CompaniesPage.jsx`, `web/src/admin/CompanyDetailPage.jsx`, `web/src/admin/BranchForm.jsx`, `web/src/business/KeywordsPage.jsx`, an appended `ckw-` block in `web/src/styles.css`, `SPEC.md`, `docs/plans/04-company-keywords/RESULT.md` (new).

## Tasks
1. **Split the picker (M8).** Create `KeywordChecklist` (controlled: `categoryId`, `selectedIds`, `onChange`, `disabled`): searchable list of active library keywords (load once with `categories(name)`), filter category + General with "Show all", counter `n / 10`, extras disabled at 10, archived selected items shown dimmed with an "archived" pill, new picks go last. Refactor `BranchKeywordsPicker` to use it with no behaviour change (same props, load from `branch_keywords`, save via `set_branch_keywords`, same messages). Create `CompanyKeywordsPicker` (props `companyId`, `categoryId`, `onSaved`): loads `company_keywords` ordered by `position`, saves via `supabase.rpc('set_company_keywords', { p_company_id, p_keyword_ids })`, maps errors like the branch picker plus `unknown company`, shows "Saved".
2. **Company form (M7).** Add a "Review keywords" section with `KeywordChecklist` (category from the form's selected category). Editing an existing company preloads `company_keywords`. Save order: insert (or update) the company, then call `set_company_keywords` with the selected ids (also when empty on edit, so removals persist). If the company saved but the RPC failed: keep the dialog open, store the returned company id in state so a retry updates instead of inserting, and show "Company saved, but keywords could not be saved: <message>. Try again." Call `onSaved()` so the list refreshes; close the dialog only after both succeed. Never write `company_keywords` directly.
3. **Business Admin page (M9).** At the top a "Company keywords" card using `CompanyKeywordsPicker` (company id and category from the existing company query). Relabel the branch cards "Branch override" with the note "Leave empty to use the company's keywords." and add a "Clear override" button that saves an empty list through the existing branch RPC path. Apply the same label and note to the Super Admin branch keyword section (`BranchForm`/`CompanyDetailPage`).
4. **SPEC.md.** Document company keywords (table, RPC, max 10), the override/inherit rule, who can change what, and that the review page shows the effective list; update the status line to mention plan 04.
5. **RESULT.md.** One row per acceptance checkbox in `00-README.md`: verified or "not verified (needs DB/browser)" with evidence and exact manual steps. Only build and grep facts may be marked verified (build passes; `company_keywords` and `branch_keywords` are only read with `.select` in `web/src`, and written only via the two RPCs). Row 1 and the DB rows depend on slice 01 running in parallel: mark them not verified and reference its Result. Do not tick Status boxes for this slice.

## Done when
- `cd web && npm run build` passes; `grep -rn "company_keywords\|branch_keywords" web/src` shows only `.select` reads (plus the RPC calls using `set_company_keywords` / `set_branch_keywords`).
- The branch picker's props and behaviour are unchanged (state this and the evidence in Result).
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
Changed: `web/src/shared/KeywordChecklist.jsx` (new), `web/src/shared/CompanyKeywordsPicker.jsx` (new, also exports `companyKeywordsMessage`, `loadCompanyKeywords`), `web/src/shared/BranchKeywordsPicker.jsx` (now wraps the checklist), `web/src/admin/CompanyForm.jsx`, `web/src/admin/BranchForm.jsx` (label "Branch override" + note), `web/src/business/KeywordsPage.jsx`, `web/src/styles.css` (`ckw-` block), `SPEC.md`, `RESULT.md` (new). `CompaniesPage.jsx` and `CompanyDetailPage.jsx` needed no change (`onSaved` is already `reload`; the branch keyword section lives in `BranchForm`).
Checks: `cd web && npm run build` PASS. grep of `company_keywords|branch_keywords` in `web/src`: only `.select` reads plus the `set_company_keywords` / `set_branch_keywords` RPC calls.
Branch picker: props and save/load unchanged; one difference: checked rows are ordered by pick order (previously selected-first by sort order). `KeywordChecklist` takes one extra optional prop `archivedKeywords`, and loads the active library itself.
Not run: DB and browser checks (see RESULT.md for manual steps). Status boxes not ticked.
