# 01/04 — Acceptance: SPEC update and checklist evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Haiku · Prerequisites: 01/02, 01/03 · Parallel with: none

## Decisions you need
All of C1–C13 for wording — run `grep -E '^\| C' 00-README.md`. The acceptance list is under `## Acceptance checklist` in `00-README.md`.

## Read first
- `SPEC.md` (sections 1–5, 8, 9, 11), `00-README.md`, and the `## Result` sections of slices 01–03.

## Scope (files you own)
`SPEC.md`, `docs/plans/01-category-subcategory/RESULT.md` (new), and the Status checkboxes in `00-README.md`.

## Tasks
1. **SPEC.md.** Update: roles (§2), data model (§3: categories, subcategories, keywords, `companies.subcategory_id`, feedback `keywords`; remove questions and question_requests), customer flow (§4: keywords and composed review draft), admin features (§5: taxonomy screen, no questions/requests), security (§6: server-side keyword validation replaces answer validation), out of scope (§8), acceptance criteria (§9: rewrite items 1, 2, 6, 7 for keywords). Replace the "DRAFT, awaiting approval" status line with the current state; delete obsolete open questions.
2. **RESULT.md.** One row per acceptance checkbox in `00-README.md`: pass/fail plus evidence (command output summary or slice Result reference). Mark anything not verified as "not verified". Tick Status boxes in `00-README.md` only for slices whose `## Result` exists.
3. **Known gaps.** List leftovers found (unused CSS, remaining "question" strings) in RESULT.md; do not fix code.

## Done when
- `grep -n -i "question" SPEC.md` shows no references to questions as a feature.
- RESULT.md has one row per checklist item.
- Append `## Result`.

## Result
- **Changed:** `SPEC.md` (rewritten for the keyword model; status line replaced; sections 1–6, 8, 9 updated; section 10 names `rls.sql`; section 7 and section 11 unchanged). `docs/plans/01-category-subcategory/RESULT.md` (new): one row per acceptance checkbox with evidence and manual steps. `00-README.md` unchanged (slice 04 Status box not ticked; acceptance boxes left for the owner to tick after manual checks).
- **Checks:** `grep -n -i question SPEC.md` → only the status line, the "Removed:" line and the section 11 heading; no feature references → PASS. `cd web && npm run build` → PASS. Seed static parse → 8 categories / 29 subcategories / 205 keywords, PASS. `composeReview` node run on C8 examples → PASS. Greps for removed question/request symbols in `web/src` and `supabase/tests`/`functions` → no matches. `supabase db reset` and `psql -f supabase/tests/rls.sql` → NOT RUN (no database here); browser checks NOT RUN.
- **Deviations:** none from the plan's decisions. `SPEC.md` section 11 kept all six open questions, since none concerns questions and none was resolved.
- **Known gaps:** listed in `RESULT.md` (dead `.notif-req` CSS, stale "Request page" CSS comment, unrendered `GetStarted.jsx`, case-insensitive category name collision risk, Business Admin branch-visibility reading to confirm).
- **For the owner:** the acceptance rows marked "not verified (needs DB/browser)" in `RESULT.md` each list exact steps to run after applying the migration locally.
