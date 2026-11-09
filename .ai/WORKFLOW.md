# AI Task Workflow

## Phase 1 — Understand

Read the user's requirement carefully.

Determine:
- What the user wants.
- Current behavior, if known.
- Expected behavior.
- Affected application/module.
- Whether this is a bug, feature, enhancement, UI change, API change, database change, or combination.

If screenshots are provided, distinguish the current implementation from the requested design.

## Phase 2 — Repository Investigation

Do not modify files during this phase.

Inspect the actual repository.

Where relevant inspect:
- Routes
- Pages
- Components
- Hooks
- State management
- Services
- APIs
- Controllers
- Models
- Database migrations
- Validation
- Authentication/authorization
- Localization
- Existing UI components
- Tests
- Related implementations elsewhere

Trace the real flow rather than guessing.

## Phase 3 — Find Reusable Functionality

Before proposing new code, search for existing implementations.

Reuse existing:
- Components
- APIs
- Services
- Hooks
- Stores/contexts
- Validation
- Business logic
- Notifications
- Loading states
- Persistence

Do not create duplicate systems unless the repository proves they are necessary.

## Phase 4 — Generate the Implementation Prompt

After investigation, create a detailed implementation prompt.

The prompt should translate:

USER REQUIREMENT
+
ACTUAL REPOSITORY FINDINGS
+
TECHNICAL REQUIREMENTS
+
CONSTRAINTS
+
VALIDATION

into an executable engineering specification.

Include relevant sections such as:
- Title
- Context
- Current behavior
- Root cause, for bugs
- Required behavior
- Scope
- Actual files/components involved
- Existing functionality to reuse
- Frontend changes
- Backend changes
- API changes
- Database changes
- UI/design requirements
- Validation
- Error handling
- Loading states
- Responsive behavior
- Localization
- Security
- Edge cases
- Testing
- Final verification

Only include sections relevant to the task.

Do not invent technical details.

## Phase 5 — Approval Gate

After presenting the implementation prompt:

STOP.

Do not:
- Modify files
- Create files
- Delete files
- Run migrations
- Change database
- Commit code
- Deploy code
- Implement the feature

End with:

**Implementation has NOT started. Waiting for your approval.**

## Phase 6 — Approved Implementation

Only begin after explicit approval such as:
- Approved
- Go ahead
- Implement it
- Proceed
- Start implementation
- Yes, proceed

Then:
1. Re-read the approved prompt.
2. Implement only the approved scope.
3. Test it.
4. Review git diff.
5. Report what changed.

## Phase 7 — Material Discovery

If implementation discovers something that materially changes:
- Architecture
- Database
- API contract
- Security
- Scope
- User-visible behavior

STOP.

Explain:
1. What was discovered.
2. Why it matters.
3. What needs to change.
4. The revised implementation prompt.

Wait for approval again.

## Prompt Quality Rule

Prompt complexity should match implementation complexity.

A one-line UI bug may need a concise prompt after investigation.

A cross-application/database feature may require a comprehensive prompt.

Never add requirements that the user did not request and the repository does not justify.
