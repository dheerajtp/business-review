# 04 — Company keywords (chosen at company creation) with branch override

Master plan: none (`SPEC.md` is updated in slice 02) · Builds on: [`../02-keyword-library/00-README.md`](../02-keyword-library/00-README.md) (amends K6, K7, K10), [`../03-prune-empty-categories/00-README.md`](../03-prune-empty-categories/00-README.md)

## Goal
- When Super Admin creates (or edits) a company they also choose up to 10 keywords from the library. These are the company's keywords.
- The review page `/f/{slug}` offers the keywords the company opted for. A branch may override with its own picks; a branch with no picks inherits the company's.
- Super Admin and the company's Business Admin can change the company keywords later.

## Decisions (already made; do not revisit)
| # | Decision |
| --- | --- |
| M1 | **Table.** New migration `supabase/migrations/20261120000001_company_keywords.sql` (never edit earlier ones). `company_keywords(company_id uuid → companies, keyword_id uuid → keywords, position int not null check (position between 1 and 10), primary key (company_id, keyword_id), unique (company_id, position))`, index on `keyword_id`. RLS on; revoke all from anon/authenticated; `grant select` to authenticated; policies `company_keywords_super` (select, super_admin) and `company_keywords_own` (select, business_admin and `company_id = current_company_id()`). No insert/update/delete grants for anyone. |
| M2 | **Write RPC.** `set_company_keywords(p_company_id uuid, p_keyword_ids uuid[]) returns void`, security definer, `set search_path = public`, `revoke all from public`, execute to `authenticated` only. Same rules as `set_branch_keywords`: role `super_admin`, or `business_admin` with `p_company_id = current_company_id()`, else `42501 'forbidden'`; company not found → `P0002 'unknown company'`; null = empty; duplicates merged keeping first position; more than 10 distinct → `22023 'too many keywords'`; every id an existing **active** keyword else `22023 'unknown keyword'`; atomic replace with positions 1..n; lock the company row (`select ... for update`). |
| M3 | **Resolution rule.** A branch's effective keywords = its `branch_keywords` rows if it has at least one, otherwise the company's `company_keywords`. Zero branch rows means "inherit". Implemented once as an internal SQL function `public.effective_keyword_ids(p_branch_id uuid) returns table (keyword_id uuid, position int)`, `security definer`, `set search_path = public`, `revoke all from public` and **no** grant (only called from the two customer RPCs, which are security definer). |
| M4 | **Form RPC.** `get_feedback_form(p_slug)` keeps every current field; `keywords` = effective keywords (M3) that are active, ordered by `position`, `[{id,label}]`, max 10. None at either level = empty list. Replaces the plan 02 K6 source. Same grants and not-found rules. |
| M5 | **Submit RPC.** `submit_feedback(p_slug, p_rating, p_keyword_ids, p_comment, p_contact)` keeps its signature, error codes, flood control and snapshot shape; keywords must be active and in the branch's effective set (M3), cap 10 distinct. Replaces the plan 02 K7 source. |
| M6 | **Existing data.** No data migration: existing companies start with no company keywords; branches that already have picks keep them as overrides; branches with none show no chips until the company picks keywords. |
| M7 | **Company form (Super Admin).** `CompanyForm` gets a "Review keywords" section: a controlled checklist (search, default filter = the form's selected category + General with "Show all", counter `n / 10`, extras disabled at 10, pick order = position). Save order: insert/update the company, then call `set_company_keywords(company_id, ids)`. If the company saved but the RPC fails, keep the dialog open, remember the new company id (so a retry updates instead of inserting a duplicate) and show "Company saved, but keywords could not be saved: <mapped error>. Try again." Skipping keywords is allowed (empty list). Error mapping as plan 02 K10, plus `unknown company`. Editing an existing company preloads its current picks from `company_keywords`. |
| M8 | **Shared picker split.** Extract the controlled checklist from `web/src/shared/BranchKeywordsPicker.jsx` into `web/src/shared/KeywordChecklist.jsx` (props: `categoryId`, `selectedIds`, `onChange`, `disabled`); `BranchKeywordsPicker` keeps its load/save behaviour on top of it; new `web/src/shared/CompanyKeywordsPicker.jsx` (load from `company_keywords`, save via `set_company_keywords`) for the Business Admin page. Behaviour of the existing branch picker must not change. |
| M9 | **Business Admin page `/business/keywords`.** Top card "Company keywords" (company picker, applies to every branch without its own list). Below, the branch cards from plan 02 relabelled "Branch override" with the note "Leave empty to use the company's keywords." and a "Clear override" button that saves an empty list. The Super Admin branch keyword section carries the same label and note. |
| M10 | **Tests.** `supabase/tests/rls.sql` gains: `company_keywords` RLS (super sees all, business admin own company only, anon nothing, no direct writes for any role); `set_company_keywords` (super ok; own company ok; other company `42501`; 11 ids rejected; archived/unknown rejected; replace and ordering; duplicates merged); effective rule (branch override wins; branch with zero rows inherits the company list; archived keyword hidden; no picks at either level = `[]`); `submit_feedback` accepts an inherited keyword and rejects a keyword outside the effective set. |
| M11 | **Out of scope (later).** Copying company keywords into branches, a keyword usage report, changing the library, per-category default keyword sets. |

## Status
- [x] 01 — Table, RPC, effective-keyword resolution, form/submit RPCs, tests (static review only; DB tests NOT RUN, user applies migration)
- [x] 02 — Company form picker, shared picker split, Business Admin page, SPEC, acceptance evidence (gated while 01 in flight; browser/DB checks NOT RUN)

## Dependencies and parallel tracks
| Slice | Prerequisites | Parallel with | Model | Files touched |
| --- | --- | --- | --- | --- |
| 01 | none | 02 (contract fixed by M1–M5) | Opus (security-definer RPCs, RLS) | `supabase/migrations/20261120000001_company_keywords.sql` (new), `supabase/tests/rls.sql` |
| 02 | none (needs 01 applied only to try it in the browser) | 01 | Sonnet | `web/src/shared/KeywordChecklist.jsx` (new), `web/src/shared/CompanyKeywordsPicker.jsx` (new), `web/src/shared/BranchKeywordsPicker.jsx`, `web/src/admin/CompanyForm.jsx`, `web/src/admin/CompaniesPage.jsx`, `web/src/admin/CompanyDetailPage.jsx`, `web/src/admin/BranchForm.jsx`, `web/src/business/KeywordsPage.jsx`, `web/src/styles.css` (appended `ckw-` block), `SPEC.md`, `docs/plans/04-company-keywords/RESULT.md` |

Disjoint files, so they run in parallel. The customer review page needs no change: it already renders `form.keywords`, and M4 changes only where that list comes from. Acceptance is folded into slice 02 (small plan).

**Rules for every slice:** read `CLAUDE.md` and `.ai/ENGINEERING_RULES.md` first; implement only the slice scope; no commits; `cd web && npm run build` must pass for web slices; SQL is written and statically reviewed only (the user applies migrations); never touch a remote Supabase project; append `## Result` to the slice file.

## Acceptance checklist
- [ ] After the migration, `rls.sql` prints `ALL RLS TESTS PASSED`; `company_keywords` cannot be written directly by any role.
- [ ] The New company dialog has a keyword section (max 10, 11th disabled); saving creates the company and its keywords; a keyword-save failure keeps the dialog open without creating a duplicate on retry.
- [ ] Editing a company shows its current keywords and saves changes.
- [ ] `/f/{slug}` of a branch with no override shows the company's keywords in picked order; a branch with its own picks shows only those; clearing the override returns to the company's.
- [ ] Business Admin can change their company's keywords and their branches' overrides at `/business/keywords`, and cannot change another company's.
- [ ] Submit accepts an inherited keyword and rejects one outside the branch's effective set or more than 10.
- [ ] The existing branch picker behaves as before (up to 10, save, archived shown dimmed).
- [x] `SPEC.md` describes company keywords, the override rule and Business Admin rights.
