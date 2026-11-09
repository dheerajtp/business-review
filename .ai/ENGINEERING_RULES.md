# Engineering Rules

## 1. Repository Evidence First

Never claim a file, component, endpoint, field, function, API response, or behavior exists unless it has been inspected.

If something cannot be verified, say:

`Not verified in the repository.`

Never hallucinate implementation details.

## 2. Minimal Correct Change

Prefer the smallest correct change.

Do not:
- Refactor unrelated code.
- Replace existing architecture unnecessarily.
- Introduce abstractions without need.
- Add dependencies without justification.
- Modify unrelated functionality.

## 3. Reuse Existing Architecture

Prefer existing:
- Components
- Services
- APIs
- State management
- Validation
- Error handling
- Loading states
- Toasts
- Localization
- Authentication
- Authorization

Avoid duplicate business logic.

## 4. Database Safety

Unless explicitly authorized otherwise:

Existing database columns must not be:
- Renamed
- Resized
- Type-changed
- Constraint-changed
- Deleted
- Repurposed in a way that changes their existing meaning

New columns may be added.

Prefer additive migrations.

Always inspect the current schema and migrations before proposing database changes.

Preserve existing data and legacy behavior.

## 5. API Safety

Before changing an API, inspect:
- Route
- Method
- Request
- Validation
- Authorization
- Controller
- Service
- Model
- Response
- Existing consumers

Prefer additive/backward-compatible changes.

Do not create duplicate endpoints when an existing endpoint can support the requirement.

## 6. UI Safety

For UI changes:
- Inspect existing design patterns.
- Reuse existing components/styles.
- Match provided client screenshots when applicable.
- Preserve unrelated page functionality.
- Check responsive behavior.
- Preserve existing interactions.

Do not turn a focused request into a page-wide redesign.

## 7. Localization

When the project uses localization:
- Use translation keys.
- Do not hardcode user-facing strings unnecessarily.
- Add translations using the existing architecture.
- Do not hardcode language lists when availability is backend-driven.

## 8. Security

Never expose or log:
- Passwords
- Authentication tokens
- Payment credentials
- Bank details
- Private account information
- Other secrets

Do not commit secrets.

## 9. Testing

Validate both new behavior and existing behavior.

For UI, test:
- Normal flow
- Loading
- Error
- Success
- Existing navigation/interactions
- Responsive behavior
- Console errors

For API, test:
- Valid request
- Invalid request
- Authorization
- Response shape
- Error behavior

For database changes, verify migrations are safe and existing data is preserved.

## 10. Final Diff Review

Before declaring implementation complete:

```text
git status
git diff
```

Confirm:
- Only relevant files changed.
- No debug code remains.
- No secrets were added.
- No unrelated refactor was introduced.
- No generated/temp files were accidentally committed.
