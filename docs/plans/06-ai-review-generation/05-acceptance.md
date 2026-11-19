# 06/05 — Acceptance: SPEC, runbook, checklist evidence

Plan folder: [`00-README.md`](00-README.md) · Model: Haiku · Prerequisites: 06/02, 06/03, 06/04 · Parallel with: none

## Decisions you need
A1–A14 for wording — run `grep -E '^\| A' 00-README.md`. The acceptance list is under `## Acceptance checklist` in `00-README.md`.

## Read first
- `SPEC.md` (sections 2–6, 8–10), the `## Result` of slices 01–04 here, `docs/plans/05-nfc-write-everywhere/RESULT.md` (format to follow).

## Scope (files you own)
`SPEC.md`, `docs/plans/06-ai-review-generation/RESULT.md` (new), Status boxes in this plan's `00-README.md`.

## Tasks
1. **SPEC.md.** Add: the AI settings page and who can use it, Vault-stored write-only key, the four providers, the generate-review flow and limits, the customer button and fallback, what data is sent to the provider (business name, branch name, category, rating, keywords; never contact or free text), the A14 policy note; update roles, data model (`ai_settings`, `ai_providers`, `ai_generation_log`), security, acceptance and the status line.
2. **RESULT.md.** One row per acceptance checkbox in `00-README.md`: verified or "not verified (needs DB/browser/provider key)" with evidence and exact manual steps. Only build, grep and node-helper facts may be marked verified. Add a **Runbook** section: enable Vault, apply the migration after `20261120000001_company_keywords.sql`, `supabase functions deploy generate-review` and `supabase functions deploy test-ai`, open `/admin/ai`, save a key, Test, set active provider, enable. Add a **Known gaps** list from the slice Results (anything skipped or NOT RUN).
3. **Status.** Tick Status boxes only for slices with a `## Result`. Do not tick acceptance rows that are not verified.

## Done when
- RESULT.md has one row per checklist item plus the Runbook and Known gaps sections.
- `grep -n -i "api key\|secret" SPEC.md RESULT.md` shows no real key material.
- Append `## Result`.

## Result
- Changed: `SPEC.md` (repo root; status line, objective, roles, data model, customer AI draft step, `/admin/ai` admin feature, AI security subsection, out-of-scope list, acceptance item 9, testing note), `docs/plans/06-ai-review-generation/RESULT.md` (new: checklist rows, runbook, known gaps), `docs/plans/06-ai-review-generation/00-README.md` (Status 05 ticked; acceptance row "SPEC.md and the runbook describe..." ticked after grep).
- `web && npm run build` → PASS (re-run in this slice).
- `grep -n -i "api key\|secret" SPEC.md RESULT.md` → only descriptive text; no key-like strings (`sk-`, `AIza`, `sk-ant-`) found → PASS.
- grep for `ai_settings|ai_providers|ai_generation_log|Vault|generate-review|test-ai` in SPEC.md → 11 matching lines → PASS.
- All other acceptance checklist rows → NOT verified (needs DB, browser, deployed functions or provider key); each row in RESULT.md gives the manual steps.
- Facts used: `Deno.env` reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in both functions; `/admin/ai` placeholders `gemini-2.5-flash`, `claude-haiku-5-5`, `gpt-4o-mini` are unverified against live provider docs.
- Surprising: no other issues. Known gaps are listed in RESULT.md.
