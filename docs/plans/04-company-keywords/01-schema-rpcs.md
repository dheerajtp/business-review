# 04/01 — Table, RPC, effective-keyword resolution, form/submit RPCs, tests

Plan folder: [`00-README.md`](00-README.md) · Model: Opus · Prerequisites: none · Parallel with: 04/02 (disjoint files; the contract is fixed by M1–M5)

## Decisions you need
M1 (table, RLS), M2 (set_company_keywords), M3 (effective rule), M4 (form RPC), M5 (submit RPC), M6 (no data migration), M10 (tests) — run `grep -E '^\| (M1|M2|M3|M4|M5|M6|M10) ' 00-README.md`.

## Read first
- `supabase/migrations/20261118000001_keyword_library.sql`: `branch_keywords` table and policies, `set_branch_keywords` (copy its structure for `set_company_keywords`), and the current `get_feedback_form` and `submit_feedback` bodies (you will `drop` and recreate both with identical signatures).
- `supabase/migrations/20261117000001_taxonomy.sql`: only for context on how the earlier versions of those two functions were built (flood control, error codes).
- `supabase/tests/rls.sql`: the branch-keyword sections (fixtures for keywords, branch picks, `set_branch_keywords` cases, form and submit checks) to mirror and extend; `_ids` temp table and `do $$ ... assert` style.

## Scope (files you own)
- `supabase/migrations/20261120000001_company_keywords.sql` (new)
- `supabase/tests/rls.sql`

## Tasks
1. **Table (M1).** Create `company_keywords` with the constraints and index from M1, enable RLS, revoke all from anon/authenticated, `grant select` to authenticated, create the two select policies (mirror `branch_keywords_super` / `branch_keywords_own`, using `current_company_id()`).
2. **set_company_keywords (M2).** Copy `set_branch_keywords` and adapt: company lookup with `select ... for update` (`P0002 'unknown company'`), role check (`42501 'forbidden'`), set-based validation (distinct ids with first position, count ≤ 10 else `22023 'too many keywords'`, all active else `22023 'unknown keyword'`), delete then insert positions 1..n. `revoke all ... from public; grant execute ... to authenticated`.
3. **effective_keyword_ids (M3).** `public.effective_keyword_ids(p_branch_id uuid) returns table (keyword_id uuid, position int)`: if `exists (select 1 from branch_keywords where branch_id = p_branch_id)` return those rows, else the company's `company_keywords` rows for the branch's company. security definer, `set search_path = public`, `language sql stable`, `revoke all ... from public` and no grant.
4. **Form and submit RPCs (M4, M5).** `drop function` both with their current signatures, recreate with identical signatures, grants (anon + authenticated), security definer and `search_path`. Replace only the keyword source: use `effective_keyword_ids(branch.id)` joined to active `keywords`, ordered by `position`. Keep every other check, error code, flood control and the snapshot shape.
5. **Tests (M10).** Add the sections listed in M10; keep all existing sections passing. Note: existing fixtures where a branch has picks keep working as overrides; add new fixtures (a company with company keywords and a branch with none) rather than changing existing ones, and re-check that earlier assertions about branches with no picks still expect `[]` (give that fixture's company no company keywords).

## Done when
- Static review passes: statement order, every referenced object exists, function signatures identical to the dropped ones, `$$` balanced. No database here: report DB checks NOT RUN; the user applies the migration after `20261119000001_prune_empty_categories.sql`.
- No existing assertion in `rls.sql` is weakened.
- Append `## Result`.

## Result
Status: DONE (static review only; no database in this environment).

Files:
- `supabase/migrations/20261120000001_company_keywords.sql` (new): `company_keywords` table (M1 constraints, `company_keywords_keyword_id_idx`, RLS, revoke all from anon/authenticated, select to authenticated, policies `company_keywords_super` / `company_keywords_own`); `set_company_keywords(uuid, uuid[])` copied from `set_branch_keywords` (role check, `select ... for update` on the company with `P0002 'unknown company'`, dedupe/cap/active validation, delete + insert 1..n; execute to authenticated only); `effective_keyword_ids(uuid) returns table (keyword_id uuid, position int)` (sql stable security definer, branch rows else company rows, revoke from public, no grant; archived keywords are filtered by the callers); `get_feedback_form(text)` and `submit_feedback(text, int, uuid[], text, text)` dropped and recreated with identical signatures, grants and checks, keyword source replaced by `effective_keyword_ids(b.id)` joined to active keywords ordered by `position`.
- `supabase/tests/rls.sql`: seed check "no company picks after migration"; new sections before "user without profile" (new fixtures Leaf Co `20000000-...-03` on subcategory Tea room, branches `leaf1` `30000000-...-03` with no picks and `leaf2` `30000000-...-04`): set_company_keywords super cases (dedupe, replace, order, positions, null clears, 11 ids, archived, random, null element, unknown company, unchanged after rejects, no direct writes), BA own company only / other company 42501 / no direct writes, BA2 isolation, super sees all, anon no read/write/RPC, effective_keyword_ids not callable by anon or authenticated, effective rule (inherit, override wins incl. brew1 vs Brew Co keywords, cleared override inherits, archived company keyword hidden + rejected + row kept, none at either level = [] for silk1), submit accepts inherited keywords (snapshot checked) and rejects keywords outside the effective set. No-profile section also checks `company_keywords` count 0 and `set_company_keywords` 42501. Fixtures were added late so earlier company/branch/feedback counts are unchanged; no existing assertion was edited.

Checks:
- Static review: statement order (table before functions; `effective_keyword_ids` created before the two RPCs that use it; drop then create), referenced objects exist (`current_app_role`, `current_company_id`, `companies`, `branches`, `keywords`, `branch_keywords`), signatures identical to the dropped ones, `$$` count even in both files (8 and 86) → PASS
- DB checks (apply migration, run `00_stubs.sql` + `rls.sql`) → NOT RUN: no supabase CLI / psql / postgres here; user applies the migration after `20261119000001_prune_empty_categories.sql`.

Facts for 04/02: RPC is `set_company_keywords(p_company_id uuid, p_keyword_ids uuid[])` returning void; errors `42501 forbidden`, `P0002 unknown company`, `22023 too many keywords` / `unknown keyword`. Read picks with `select keyword_id, position from company_keywords where company_id = ...` (RLS-scoped for authenticated).
