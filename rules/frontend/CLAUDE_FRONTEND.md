# React Frontend Engineering Rules

These rules apply to React applications, including Vite-based applications.

## JavaScript Only — NON-NEGOTIABLE

All frontend code is plain JavaScript (`.jsx` / `.js`). Do not use TypeScript: no `.ts` / `.tsx` files, `tsconfig.json`, `typescript` or `@types/*` packages, type annotations, interfaces, or generics. This applies even when a skill, template, or library example uses TypeScript.

If a language choice is ever unclear, ask before scaffolding.

## 1. Repository First

Before changing UI code, inspect the existing routing, page structure, components, hooks, state management, API/data access, validation, authentication, authorization, localization, styling, assets, and tests relevant to the request.

Never invent an existing component, hook, route, API, store, utility, design token, or behavior.

## 2. Minimal Correct Change

Implement the smallest change that satisfies the requirement. Do not perform unrelated refactors, redesigns, dependency replacements, or architecture migrations.

Reuse existing components, hooks, utilities, styles, data-access functions, notifications, loading states, and error handling whenever appropriate.

## 3. ONE JSX-RENDERING COMPONENT PER FILE — NON-NEGOTIABLE

A React file MUST NOT contain multiple independent JSX-rendering component/view functions.

Do not bypass this rule with functions such as `renderHeader()`, `renderTable()`, `renderForm()`, or similar helpers when those helpers return JSX and represent independent UI sections.

Use one primary React component/view per file. If a section becomes an independent component, place it in its own file.

Small non-JSX helpers are allowed.

## 4. Confirmation Modals

Use a React Portal for confirmation modals so they render outside the normal component stacking context.

A confirmation is required before:
- logout when the product flow requires confirmation
- delete
- bulk delete
- delete all
- remove all
- clear all
- other irreversible destructive actions

Reuse the existing confirmation/modal system when one exists.

## 5. State and Async Behavior

Handle loading, success, empty, error, retry, cancellation, and stale-response/race conditions where applicable.

Prevent duplicate submissions and accidental repeated destructive actions.

Clean up subscriptions, timers, event listeners, and realtime connections.

Do not leave state updates running after an operation has become irrelevant or a component has unmounted.

## 6. Forms and Validation

Validate user input before submission for good UX, but frontend validation is never a security boundary.

Display field-level and request-level errors using existing project patterns.

Preserve entered values when safe and useful after validation failures.

## 7. Authentication and Authorization

Do not treat hidden UI elements as authorization.

Use the application's real authentication and authorization state. Handle loading/unknown permission state without briefly exposing restricted UI.

Never store or expose privileged server credentials in frontend code.

## 8. API/Data Contracts

Inspect the real request and response contract before changing consumers.

Do not silently change response shapes, field names, types, or assumptions used elsewhere.

Keep user-facing behavior backward compatible unless the requirement explicitly changes it.

## 9. Localization

Use the project's existing translation architecture.

Do not unnecessarily hardcode user-facing strings when translations are supported.

Do not hardcode available/active language lists when the application is designed for backend-driven languages.

Apply localization consistently across all affected pages and user-facing UI.

## 10. Accessibility

Use semantic HTML, keyboard-accessible interactions, labels, accessible names, focus management, and appropriate ARIA only when necessary.

Dialogs must manage focus correctly.

Do not rely on color alone to communicate state.

## 11. Security

Prevent XSS and unsafe HTML rendering. Sanitize or safely render any untrusted HTML.

Never expose API secrets, service-role credentials, private keys, tokens, passwords, or payment credentials.

Treat Vite/client environment variables as public.

## 12. Responsive UI

Inspect existing breakpoints and layout conventions. Preserve responsive behavior and test the requested flow at relevant viewport sizes.

Do not redesign the whole page for a focused change.

## 13. Performance

Avoid unnecessary rerenders, duplicate network requests, oversized dependencies, unbounded lists, and repeated expensive computations.

Use pagination, virtualization, memoization, lazy loading, or caching only when justified by the actual repository and workload.

## 14. Testing

For changed UI behavior, verify normal, loading, empty, error, success, navigation, validation, permissions, responsive behavior, and browser-console behavior as applicable.

Add or update automated tests when the repository has an established testing setup and the change warrants coverage.

## 15. Final Review

Before completion:
- inspect `git status`
- inspect the relevant diff
- remove debug code/logging
- verify no secrets were added
- verify no unrelated files changed
- verify no accidental redesign or dependency change was introduced
