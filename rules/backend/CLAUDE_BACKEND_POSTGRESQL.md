# PostgreSQL Backend Engineering Rules

These rules apply to applications using PostgreSQL as the primary database, with a Node.js/API backend where applicable.

## 1. Repository First

Inspect actual routes, validators, authentication, authorization, controllers/services, repositories/ORM usage, schema, migrations, indexes, transactions, queues, integrations, tests, and configuration before changing backend behavior.

Never invent existing endpoints, tables, columns, constraints, functions, services, or business logic.

## 2. Every POST Request Must Have Backend Validation — NON-NEGOTIABLE

Every POST request body MUST be explicitly validated at the backend before business logic, database writes, external calls, queue publication, or event publication.

Frontend validation never replaces backend validation.

Validate path/query parameters, headers, authentication context, and file metadata where applicable.

## 3. Minimal Correct Change

Implement the smallest correct change. Reuse existing validators, services, repositories, middleware, error handling, transaction patterns, and response conventions.

Do not duplicate business logic or introduce abstractions without evidence they are needed.

## 4. Database Safety — NON-NEGOTIABLE

Existing database columns must not be renamed, removed, repurposed, resized, type-changed, or have constraints/semantics changed without explicit approval.

New columns may be added when necessary and compatible.

Inspect the live schema assumptions, migration history, ORM models, indexes, foreign keys, triggers, views, functions, and consumers before modifying data structures.

Prefer additive, backward-compatible migrations and preserve existing data.

## 5. Migrations

Every schema change must be represented through the repository's established migration mechanism.

Migrations must be deterministic, reviewable, reversible where practical, and safe for existing production data.

Avoid long blocking operations on large production tables without an explicit migration strategy.

Do not edit historical migrations that may already have been applied unless the project explicitly uses an approved migration-reconciliation process.

## 6. SQL and ORM Safety

Use parameterized queries or the ORM's safe query mechanisms.

Never concatenate untrusted input into SQL.

Review generated SQL for important queries and avoid N+1 patterns.

Use explicit projections and pagination for large datasets.

## 7. Transactions and Consistency

Use transactions when multiple related writes must succeed or fail atomically.

Keep transaction scope short and avoid unnecessary external HTTP calls inside database transactions.

Do not publish external events as successful before required database state is committed.

Use an outbox/event pattern when reliable database-to-event consistency is required.

## 8. Concurrency and Idempotency

Use database constraints, unique indexes, atomic updates, row locks, or appropriate isolation levels for race-sensitive operations.

Do not rely only on application-level prechecks for uniqueness or state transitions.

Make retry-prone payment, webhook, queue, and external integration operations idempotent where appropriate.

## 9. Authentication and Authorization

Authentication establishes identity; authorization verifies access to the requested resource/action.

Enforce authorization server-side for every protected resource.

Prevent horizontal and vertical privilege escalation.

Do not trust client-supplied ownership IDs or role claims without server-side verification.

Use secure token/session lifecycle, expiration, rotation/revocation, and abuse protection appropriate to the application.

## 10. Security

Never log or expose passwords, tokens, API keys, payment credentials, private account information, or secrets.

Use secure password hashing, input validation, rate limiting, secure headers, CORS policy, request-size limits, and safe error responses where applicable.

Treat uploaded files and externally supplied URLs as untrusted.

## 11. File Uploads

Validate file size, MIME type, extension, content where necessary, filename/path handling, and storage permissions.

Prevent traversal, overwrite, and unsafe execution.

## 12. External HTTP and Webhooks

Set explicit timeouts and bounded retries.

Handle non-2xx responses and partial failures explicitly.

Verify incoming webhook signatures where supported, validate payloads, and make handlers idempotent.

Use asynchronous processing when the provider requires fast acknowledgement.

## 13. Queues and Background Jobs

Design jobs for safe retries and idempotency where required.

Use bounded retries, failure/dead-letter handling, observability, and safe replay where business-critical.

Do not put secrets into job payloads unless unavoidable and protected.

## 14. Redis/Caching

Treat cache as an optimization unless explicitly authoritative.

Define TTL and invalidation rules and prevent cross-user leakage.

Handle cache outages without corrupting primary database state.

## 15. PostgreSQL Performance

Use appropriate indexes for real query patterns.

Avoid over-indexing write-heavy tables.

Use `EXPLAIN`/`EXPLAIN ANALYZE` for important query investigations where safe.

Use connection pooling with bounded pool size and timeouts.

Avoid unbounded result sets and N+1 queries.

## 16. Row-Level Security and Database Authorization

If PostgreSQL RLS is used, treat policies as part of the security boundary and test them explicitly.

Do not assume application-level authorization makes an RLS policy unnecessary when the architecture relies on RLS.

Review service-role/admin connections separately because they may bypass normal RLS behavior.

## 17. Backups and Recovery

Production systems should have documented backup retention, restore verification, RPO, and RTO appropriate to criticality.

Recovery procedures should be tested rather than assumed.

## 18. Observability

Use structured logs, request/job identifiers, useful error metadata, and metrics for latency, failures, throughput, and background processing.

Do not log sensitive request bodies or credentials.

## 19. Testing

Test valid/invalid input, authentication, authorization, transactions, constraints, duplicate/retry behavior, migrations, error responses, and important integration paths.

Use representative data when validating performance-sensitive database changes.

## 20. CI/CD and Deployment

Run migrations through the established deployment process. Do not manually mutate production schemas when the project has a migration system.

Run tests, linting, builds, and dependency/security checks where configured.

## 21. Final Review

Inspect `git status` and the relevant diff. Confirm only approved files changed, no secrets/debug code were introduced, and no destructive or unrelated schema change was included.
