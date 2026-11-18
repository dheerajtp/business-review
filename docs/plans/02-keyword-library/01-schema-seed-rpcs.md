# 02/01 — Schema, seed, RPCs, RLS tests

Plan folder: [`00-README.md`](00-README.md) · Model: Opus · Prerequisites: none · Parallel with: none

## Decisions you need
K1 (library schema), K2 (seed), K3 (branch_keywords), K4 (set_branch_keywords), K5 (permissions), K6 (form RPC), K7 (submit RPC), K12 (tests) — run `grep -E '^\| (K1|K2|K3|K4|K5|K6|K7|K12) ' 00-README.md`.

## Read first
- `supabase/migrations/20261117000001_taxonomy.sql`: the `keywords` table, indexes, grants and policies `keywords_read`/`keywords_write` (~lines 47–80), `get_feedback_form` (~383–405), `submit_feedback` (~405–end). You will `drop`/recreate both functions.
- `supabase/migrations/20261005000001_init.sql`: `branches` table, `current_app_role()`, `current_company_id()`.
- `supabase/tests/rls.sql`: whole file (style, fixtures, `\echo` sections); keyword fixtures from plan 01 must be reworked.

## Scope (files you own)
- `supabase/migrations/20261118000001_keyword_library.sql` (new)
- `supabase/tests/rls.sql`

## Tasks
1. **Library (K1, K5).** Delete `keywords` rows, drop `subcategory_id` (and the two indexes on it), widen the label check to 1–60 (drop/re-add the check constraint by its real name; look it up), add `category_id`, `unique (lower(label))`, index `(category_id, is_active)`. Keep existing grants and policies as they are.
2. **Seed (K2).** Insert General (`category_id null`) and per-category keywords (join by `lower(categories.name)`) with `sort_order` 1..n per group, `on conflict do nothing`. Labels lower case, ≤ 60 chars, no duplicates (unique is global). Categories: Restaurants & Cafes, Retail, Healthcare, Beauty & Wellness, Hotels & Stays, Automotive, Education, Fitness. At least 10 General and 6–8 per category.
3. **branch_keywords (K3).** Create table, `unique (branch_id, position)`, `check (position between 1 and 10)`, index on `keyword_id`. Enable RLS; revoke all from anon/authenticated; `grant select` to authenticated; policies: `branch_keywords_super` (select, super_admin) and `branch_keywords_own` (select, business_admin and branch's company = `current_company_id()` via exists on `branches`).
4. **RPC set_branch_keywords (K4).** Exactly as K4. Use one set-based validation (distinct ids with `min(ord)`, count ≤ 10, all active). Delete then insert positions 1..n in one function body. `revoke all ... from public; grant execute ... to authenticated`.
5. **Form/submit RPCs (K6, K7).** `drop function` both (current signatures) and recreate with the same signatures, `security definer`, `set search_path = public`, same grants (anon + authenticated). Form: keywords from `branch_keywords` joined to active `keywords`, ordered by position. Submit: keep every existing check and error code; validate ids against active keywords picked for the branch; cap 10 distinct; unchanged snapshot shape.
6. **Tests (K12).** Update `rls.sql` fixtures (library rows, branch picks) and add every check listed in K12. Keep all unrelated sections passing.

## Done when
- Static review passes: statement order, constraint names, every referenced object exists (no database in this environment unless one is available; report DB checks NOT RUN honestly; the user applies the migration).
- Seed counts by static parse: General ≥ 10, each category 6–8, no duplicate labels case-insensitively.
- No remaining reference to `keywords.subcategory_id` in `supabase/tests`.
- Append `## Result`.

## Result
**Files**
- `supabase/migrations/20261118000001_keyword_library.sql` (new): drops `get_feedback_form(text)` / `submit_feedback(text,int,uuid[],text,text)`; `delete from keywords`; drops `keywords_subcategory_label_lower_key` and `keywords_subcategory_id_is_active_idx` (auto-name from plan 01's unnamed index) and column `subcategory_id`; replaces `keywords_label_check` (auto-name of the inline check) with 1–60; adds `category_id uuid null → categories`, `keywords_label_lower_key unique (lower(label))`, `keywords_category_id_is_active_idx`. Grants/policies on `keywords` untouched. Seed: 12 General + 8 Restaurants & Cafes + 7 for each other category (69 total). `branch_keywords` table + RLS (`branch_keywords_super`, `branch_keywords_own`), select-only grant to authenticated. `set_branch_keywords(uuid, uuid[])` (K4; locks the branch row `for update` to serialize concurrent saves). Recreated form/submit RPCs (K6/K7) with the same signatures and grants.
- `supabase/tests/rls.sql`: fixtures moved to `category_id` (Wifi is General); new sections for `set_branch_keywords` (super, BA own/other, BA2, no-profile, anon), `branch_keywords` direct-write denial for super/BA/anon, archived pick hidden+rejected but row kept, no picks = `[]`; seed checks (General ≥ 10, each category 6–8, lower case ≤ 60, global unique re-run); form now asserts picked order; submit asserts not-picked rejection and 11-id cap; super library edits (category change, 60 ok / 61 and '' rejected, duplicate vs seed label).

**Checks**
- Static parse of seed (python): General 12; categories 8/7/7/7/7/7/7/7, sort_order 1..n per group; 0 case-insensitive duplicates; all lower case, max length 30; no clash with test fixture labels; category names match plan 01 C4 → PASS
- `grep subcategory_id supabase/tests` → only `companies.subcategory_id` (fixture insert); no `keywords.subcategory_id` → PASS
- Static review: statement order (functions dropped before column drop; delete before constraint change; branch_keywords after keywords/branches; RPCs after table), every referenced object exists in init/plan 01 migrations, `$$` balanced → PASS
- Applying migration / running `rls.sql` → NOT RUN (no postgres/psql/supabase CLI in this environment; user applies migrations)

**Facts for next slices**
- `keywords` columns: `id, label, category_id (null = General), sort_order, is_active, created_at`. Unique violation on `keywords_label_lower_key` for duplicates (case-insensitive, global).
- `branch_keywords(branch_id, keyword_id, position)`; read via RLS; write only via `rpc('set_branch_keywords', { p_branch_id, p_keyword_ids })`. Errors: `42501 forbidden`, `P0002 unknown branch`, `22023 too many keywords`, `22023 unknown keyword`.
- `get_feedback_form` keywords = branch's active picks by position (≤ 10); `submit_feedback` cap 10.
