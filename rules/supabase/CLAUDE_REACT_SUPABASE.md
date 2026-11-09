# React + Supabase Engineering Rules

These rules apply to React applications using Supabase for authentication, PostgreSQL, Row Level Security, Storage, Realtime, and optionally Edge Functions.

A custom Node/Express backend is not required by this architecture. Use Supabase Edge Functions only when trusted server-side execution is actually required.

## JavaScript Only — NON-NEGOTIABLE

All frontend code is plain JavaScript (`.jsx` / `.js`). Do not use TypeScript: no `.ts` / `.tsx` files, `tsconfig.json`, `typescript` or `@types/*` packages, type annotations, interfaces, or generics. This applies even when a skill, template, or library example uses TypeScript.

If a language choice is ever unclear, ask before scaffolding.

## 1. Repository First

Inspect the existing React routes/pages/components, Supabase client setup, auth flow, queries, mutations, RLS policies/migrations, Storage policies, Realtime subscriptions, Edge Functions, environment configuration, localization, and tests before changing behavior.

Never invent existing tables, columns, policies, functions, buckets, routes, hooks, or business logic.

## 2. ONE JSX-RENDERING COMPONENT PER FILE — NON-NEGOTIABLE

A React file MUST NOT contain multiple independent JSX-rendering component/view functions.

Do not bypass this rule with JSX-returning `renderHeader()`, `renderTable()`, `renderForm()`, or similar helpers.

Use one primary React component/view per file. Move independent JSX-rendering sections into their own files.

Small non-JSX helpers are allowed.

## 3. Confirmation Modals

Confirmation modals must use React Portal rendering.

Require confirmation for delete, bulk delete, delete all, remove all, clear all, and other irreversible destructive actions. Follow the existing product flow for logout confirmation where applicable.

Reuse the existing modal/confirmation implementation when present.

## 4. Supabase Security Boundary

Treat Row Level Security (RLS) as the primary database authorization boundary when the project uses it.

Frontend checks are for UX only and never replace RLS or trusted server-side authorization.

Never expose the Supabase service-role key or other privileged credentials in frontend code.

Client-side environment variables must be treated as public.

## 5. Every Data-Writing Request Must Be Trusted-Path Validated

Validate user input before database mutations, RPC calls, Storage uploads, or Edge Function invocation.

Where an Edge Function receives POST input, the function MUST validate the request body before business logic, database writes, external calls, or event publication.

Frontend validation never replaces trusted-path validation.

## 6. Database Safety

Existing Supabase/PostgreSQL columns must not be renamed, removed, repurposed, resized, type-changed, or have constraints/semantics changed without explicit approval.

New columns may be added when necessary and compatible.

Inspect existing migrations, tables, indexes, foreign keys, RLS policies, triggers, functions, and consumers before schema changes.

Prefer additive migrations and preserve existing data and behavior.

Do not manually mutate production schema when the project uses migrations.

## 7. RLS Policies

Every exposed table containing protected data must have an intentional RLS strategy.

Policies must be based on trusted identity/context such as `auth.uid()` and server-controlled relationships rather than client-supplied ownership claims.

Test both allowed and denied access paths.

Review insert, select, update, and delete policies independently.

Do not assume that hiding a button prevents unauthorized access.

## 8. Authentication

Use the established Supabase Auth flow.

Handle loading, signed-out, signed-in, expired-session, and error states explicitly.

Do not put access tokens or privileged credentials into logs or user-visible errors.

## 9. Supabase Storage

Storage bucket access must be protected by appropriate Storage policies.

Validate file size, MIME type, extension, filename/path, and content assumptions as appropriate.

Do not trust client-controlled paths to determine authorization.

Prevent unintended overwrite and path traversal behavior.

## 10. Realtime

Create subscriptions only where required.

Clean them up when components or pages unmount.

Avoid duplicate subscriptions caused by repeated renders or navigation.

Apply authorization/policy expectations to realtime data just as with normal queries.

Handle reconnect and stale-state behavior where relevant.

## 11. Queries and Performance

Select only required columns where practical.

Paginate large datasets.

Avoid N+1 requests and unnecessary refetching.

Use indexes based on actual query patterns.

Do not move large business computations into the browser when a database-side or trusted server-side operation is more appropriate.

## 12. RPC and Edge Functions

Use PostgreSQL functions/RPC only when they fit the existing architecture and provide a justified database-side operation.

Validate RPC/function inputs and enforce authorization at the appropriate boundary.

Edge Functions must validate authentication, input, authorization, and external responses before performing privileged work.

Secrets required by Edge Functions must remain server-side.

## 13. External APIs and Webhooks

Do not call secret-bearing third-party APIs directly from the browser.

Use Edge Functions or another trusted backend boundary when credentials or privileged operations are required.

Set timeouts and bounded retries where supported.

Validate incoming webhooks, verify signatures where available, and make handlers idempotent.

## 14. React UI and State

Handle loading, empty, error, success, validation, navigation, and permission states.

Prevent duplicate submissions and race conditions.

Clean up subscriptions, timers, listeners, and asynchronous work.

Reuse existing components, hooks, styles, notifications, and data-access utilities.

## 15. Localization

Use the existing translation architecture.

Do not unnecessarily hardcode user-facing strings.

Do not hardcode active/available language lists when the project uses backend-driven languages.

Apply localization consistently across all affected pages and user-facing UI.

## 16. Accessibility and Responsive UI

Use semantic HTML, accessible names, keyboard support, focus management, and appropriate dialog behavior.

Preserve the existing responsive system and do not redesign unrelated areas.

## 17. XSS and Unsafe HTML

Treat all database and user-generated HTML as untrusted unless the project explicitly establishes a trusted sanitization pipeline.

Do not use unsafe HTML rendering without understanding the source and sanitization boundary.

## 18. Testing

Test normal, loading, empty, error, success, validation, auth, authorization/RLS, realtime lifecycle, Storage behavior, and important mutation paths.

Verify denied access, not only successful access, for security-sensitive data.

## 19. Final Review

Inspect `git status` and the relevant diff. Verify no service-role keys/secrets were exposed, no destructive schema changes slipped in, no unrelated refactor was added, and no debug code remains.
