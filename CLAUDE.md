# AI Engineering Starter

This repository is a reusable AI-assisted software engineering starter kit.

## Required Reading Order

Before doing project work, Claude MUST read:

1. `.ai/README.md`
2. `.ai/PROJECT_CONTEXT.md`
3. `.ai/ENGINEERING_RULES.md`
4. `.ai/WORKFLOW.md`
5. `.ai/DECISIONS.md`
6. `STACK_CONFIG.md`
7. The technical rule files selected by `STACK_CONFIG.md`

The `.ai/` files define the universal AI engineering workflow and governance.
The `rules/` files define stack-specific implementation rules.

## Stack Selection

The only stack selector is `STACK_CONFIG.md`.

Supported values:

- `react-mongo`
- `react-postgres`
- `react-supabase`

Do not assume a stack from memory, filenames, or general project conventions. Read `STACK_CONFIG.md` and then inspect the actual repository.

## Rule Precedence

Apply rules in this order:

1. Actual repository behavior and existing implementation
2. Explicit user requirements
3. `.ai/` universal engineering rules and workflow
4. Selected stack-specific technical rules
5. General engineering conventions

If two rules appear to conflict, preserve existing project behavior unless the user explicitly approves the change, and stop for clarification when the conflict materially affects architecture, security, data, or user-visible behavior.

## Mandatory Operating Behavior

- Inspect the repository before proposing implementation details.
- Never invent existing files, functions, endpoints, database fields, components, or behavior.
- Reuse existing functionality when it satisfies the requirement.
- Prefer the smallest correct change.
- Do not modify the database schema destructively without explicit approval.
- Do not expose secrets or credentials.
- Validate backend-bound input at the trusted boundary where applicable.
- Follow the approval gate defined in `.ai/WORKFLOW.md`.
- If material discovery changes the scope or architecture, stop and return to the approval gate.

## Stack Rule Loading

### `react-mongo`

Read:
- `rules/frontend/CLAUDE_FRONTEND.md`
- `rules/backend/CLAUDE_BACKEND_MONGODB.md`

### `react-postgres`

Read:
- `rules/frontend/CLAUDE_FRONTEND.md`
- `rules/backend/CLAUDE_BACKEND_POSTGRESQL.md`

### `react-supabase`

Read:
- `rules/supabase/CLAUDE_REACT_SUPABASE.md`

For Supabase-only projects, do not invent a separate Node/Express backend unless the repository already contains one or the user explicitly requests one.

## Project-Specific Context

`.ai/PROJECT_CONTEXT.md` starts as unknown/initializing context. Update it only with stable, verified project facts when the workflow permits doing so. The actual repository remains the ultimate source of truth.

## Implementation Gate

When the workflow requires an approval gate, Claude must not modify, create, delete, migrate, commit, or deploy anything before explicit approval.

After approval, implement only the approved scope, verify the result, and review the final diff.
