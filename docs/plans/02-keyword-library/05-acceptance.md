# 02/05 — Acceptance: SPEC update and checklist evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Haiku · Prerequisites: 02/03, 02/04 · Parallel with: none

## Decisions you need
All of K1–K13 for wording — run `grep -E '^\| K' 00-README.md`. The acceptance list is under `## Acceptance checklist` in `00-README.md`.

## Read first
- `SPEC.md` (sections 2–6, 9), `docs/plans/01-category-subcategory/00-README.md` (status area), the `## Result` of slices 01–04 here, `docs/plans/01-category-subcategory/RESULT.md` (format to follow).

## Scope (files you own)
`SPEC.md`, `docs/plans/02-keyword-library/RESULT.md` (new), `docs/plans/01-category-subcategory/00-README.md` (one added line only), Status boxes in this plan's `00-README.md`.

## Tasks
1. **SPEC.md.** Update data model (global `keywords` with optional category, `branch_keywords`), roles (Super Admin manages library and picks per branch; Business Admin changes own branches' picks), customer flow (keywords under the stars for every rating, max 10, review text per K8), admin features (Keywords page, picker, `/business/keywords`), security (`set_branch_keywords` role check, submit validates against the branch's picks), acceptance criteria, and the status line.
2. **Plan 01 note.** Add under its title: `Amended by plan 02: keywords are now a global library chosen per branch (see ../02-keyword-library/00-README.md).`
3. **RESULT.md.** One row per acceptance checkbox in plan 02: verified/not verified with evidence (build, greps, static seed parse, slice Results) and exact manual steps for DB/browser rows. Never mark unrun checks as passed. List known gaps (unused CSS, leftovers).
4. **Status.** Tick Status boxes only for slices with a `## Result`.

## Done when
- `grep -n -i "subcategory" SPEC.md` shows no claim that keywords belong to a subcategory.
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
- Changed: `SPEC.md` (status line, sections 1-6, 8-10 updated for the keyword library, branch picks, Business Admin picks, RPC rules, acceptance criteria; section 7 and 11 unchanged), `docs/plans/01-category-subcategory/00-README.md` (one line added under the title), `docs/plans/02-keyword-library/RESULT.md` (new). The Status box of 05 in `00-README.md` is left unticked as instructed.
- `grep -n -i "subcategor" SPEC.md`: every hit is about categories, subcategories or `companies.subcategory_id`; the only keyword-related hit is the removal note in section 3. → PASS
- `cd web && npm run build` → PASS (`vite build` completed).
- Seed static parse of `supabase/migrations/20261118000001_keyword_library.sql`: General 12, Restaurants & Cafes 8, other seven categories 7 each (69 total); 0 case-insensitive duplicates; all lower case; max length 30 → PASS
- `node` run of `composeReview` (K8 inputs, company Acme): all eight outputs match K8 → PASS
- Database checks (`supabase db reset`, `rls.sql`) and browser checks → NOT RUN (no DB or browser here).
- Gaps for later: `.tax-grid` still 3 columns on wide screens (`web/src/styles.css` line 614, outside this slice); unused `subId` state in `web/src/admin/CategoriesPage.jsx` line 55; chips appear only after the first star tap (slice 03); migration drops constraint/indexes by auto-generated names (`keywords_label_check`, `keywords_subcategory_*`); `set_branch_keywords` takes an extra row lock on `branches` (`for update`).
- Facts: `get_feedback_form` and `submit_feedback` both read picks from `branch_keywords` (active only); `branch_keywords` is read only via `.from('branch_keywords').select` in `web/src/shared/BranchKeywordsPicker.jsx`, and written only via `rpc('set_branch_keywords')` there.
