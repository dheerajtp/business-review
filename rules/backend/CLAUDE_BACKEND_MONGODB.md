# MongoDB Backend Engineering Rules

These rules apply to applications using MongoDB as the primary database, with a Node.js/API backend where applicable.

## 1. Repository First

Inspect the actual routes, request validation, authentication, authorization, controllers/services, models, MongoDB access layer, indexes, migrations/scripts, queues, integrations, tests, and configuration before changing backend behavior.

Never invent existing endpoints, collections, fields, indexes, middleware, services, or business logic.

## 2. Every POST Request Must Have Backend Validation — NON-NEGOTIABLE

Every POST request body MUST be explicitly validated at the backend before business logic, database writes, external calls, queue publication, or event publication.

Frontend validation never replaces backend validation.

Validate path/query parameters, headers, authentication context, and file metadata where applicable as well.

Reject unexpected, malformed, oversized, or unsafe input according to the application's contract.

## 3. Minimal Correct Change

Make the smallest correct backend change. Reuse existing services, repositories, validators, middleware, error handling, logging, and response conventions.

Do not duplicate business logic merely because a new route is requested.

## 4. Database Safety

Existing database fields must not be renamed, removed, repurposed, resized, type-changed, or have constraints/semantics changed without explicit approval.

New fields may be added when necessary and compatible.

Inspect existing collections, schema validation, indexes, scripts/migrations, and production assumptions before data changes.

Prefer additive and backward-compatible changes. Preserve existing data and legacy behavior unless explicitly changed.

## 5. MongoDB Schema Design

Use document structure that matches actual access patterns.

Embed data when the lifecycle and cardinality justify it; reference data when independent lifecycle, high cardinality, or document growth makes referencing safer.

Avoid unbounded arrays and documents that can grow without practical limits.

Define indexes from real query and sort patterns rather than adding indexes speculatively.

Consider compound index field order and selectivity.

## 6. Query Safety and Performance

Use projections to avoid unnecessary data transfer.

Paginate large result sets.

Set appropriate query, cursor, socket, and operation timeouts.

Use `maxTimeMS`/equivalent safeguards where appropriate for expensive operations.

Do not load an entire collection into application memory when a database-side operation is available.

Review query plans for important or newly introduced query patterns.

## 7. Consistency and Transactions

Use MongoDB transactions only when atomicity across multiple documents/collections is actually required.

Do not introduce transactions blindly for single-document atomic operations.

Understand retry behavior and idempotency before retrying writes.

Do not publish an external event as successful when the corresponding database state was not durably committed.

Use an outbox/event pattern when reliable database-to-event consistency is required.

## 8. Concurrency and Idempotency

Design payment, webhook, queue, registration, and other retry-prone operations to be idempotent where appropriate.

Use unique indexes or atomic update patterns for uniqueness and race-sensitive operations.

Do not rely on application-level prechecks alone for uniqueness.

## 9. Authentication and Authorization

Authentication establishes identity; authorization must verify whether that identity may access the requested resource.

Enforce authorization server-side for every protected resource/action.

Do not rely on frontend route visibility or client-supplied user IDs.

Prevent horizontal and vertical privilege escalation.

Use secure session/JWT lifecycle, expiration, revocation/rotation strategy, and abuse protection appropriate to the application.

## 10. Security

Never log or expose passwords, tokens, API keys, payment credentials, private account data, or secrets.

Hash passwords with an appropriate password-hashing algorithm and cost configured for the deployment.

Use secure headers, CORS, rate limiting, input validation, output handling, and request-size limits where applicable.

Treat uploaded files and externally supplied URLs as untrusted.

## 11. File Uploads

Validate file size, MIME type, extension, content where necessary, filename/path handling, and storage permissions.

Do not allow user-controlled filenames or paths to cause traversal or overwrite attacks.

Do not execute uploaded content.

## 12. External HTTP and Webhooks

Set timeouts and bounded retries for outbound HTTP.

Handle non-2xx responses explicitly.

Authenticate incoming webhooks, verify signatures where supported, validate payloads, and make handlers idempotent.

Return acknowledgement semantics that match the provider contract.

Do not perform long-running work synchronously when the provider requires fast acknowledgement.

## 13. Queues and Background Jobs

Make jobs retry-safe and idempotent where required.

Use bounded retries and a dead-letter/failure strategy where appropriate.

Record enough context to diagnose failed jobs without storing secrets.

Support safe replay for business-critical events where the architecture requires it.

## 14. Redis/Caching

Treat Redis/cache as an optimization unless the architecture explicitly makes it authoritative.

Define TTLs and invalidation behavior.

Prevent stale or cross-user cached data.

Handle cache outages without corrupting primary data.

## 15. Backups and Recovery

For production systems, establish documented backup and recovery expectations, retention, restore verification, RPO, and RTO appropriate to the application's criticality.

Do not assume that having backups means recovery has been tested.

## 16. Replica Sets, Sharding, and Advanced MongoDB Features

Use replica sets and appropriate write/read concerns for production durability and availability.

Do not introduce sharding, change streams, time-series collections, geospatial indexes, or Atlas-specific features unless justified by actual requirements and deployment architecture.

When using change streams, manage lifecycle, resume behavior, failure handling, and cleanup.

## 17. Observability

Use structured logging and useful request/job identifiers.

Measure important latency, error, throughput, and queue metrics.

Never log sensitive payloads or credentials merely for debugging.

## 18. Testing

Test valid and invalid input, authentication, authorization, duplicate/retry behavior, database interactions, error responses, and important integration paths.

Test migration/data changes safely against representative data where applicable.

## 19. Deployment and CI/CD

Pin or control dependency versions appropriately, run security/dependency checks, linting, tests, and build verification in CI where configured.

Do not introduce deployment-breaking configuration changes without verifying environment requirements.

## 20. Final Review

Inspect `git status` and the relevant diff. Confirm only approved files changed, no debug code/secrets were added, and no unrelated refactor or schema change slipped in.
