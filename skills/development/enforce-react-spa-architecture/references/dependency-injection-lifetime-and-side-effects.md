# Dependency Injection, Lifetime, And Side Effects

## Dependency Injection Rule

Instantiate repositories, gateways, and infrastructure services at the application edge.

Preferred composition points:

- route loaders and actions
- server entry points
- worker entry points
- dedicated dependency factory modules such as `dependencies.ts`

Prefer manual DI first:

1. define a domain-facing interface
2. implement it in infrastructure
3. inject the implementation into the use case constructor
4. wire the graph in one composition root

Do not instantiate infrastructure directly inside domain models, domain services, or server use cases.

## Async And Request Safety Rule

In this stack, the main hazard is usually async overlap and request leakage.

Protect against:

- module-level mutable state on the server
- singleton services storing current user or request context
- transaction clients being reused outside their transaction scope
- caches that do not partition by tenant or user when required
- client responses arriving out of order and overwriting newer state

Prefer explicit request context, transaction-scoped repository factories, immutable client transitions, and request ordering or cancellation guards.

## Background Side Effect Rule

Treat external side effects separately from core request handling when they are slow, retryable, or operationally important.

Typical candidates:

- email sending
- webhook dispatch
- report generation
- search indexing
- long-running file export

Prefer:

- the use case decides that a side effect should happen
- an infrastructure adapter or job runner performs it
- the request path performs it inline only when latency and failure semantics are acceptable

## Lifetime Guidance

- Prefer singleton lifetime for `PrismaClient` and other expensive stateless SDK clients.
- Prefer lightweight singleton or factory-created lifetime for stateless repositories and gateways.
- Prefer request scope for auth context, correlation context, and request-specific wrappers.
- Prefer transaction scope for repositories built from a transaction handle.

Avoid storing current user id, current tenant id, current request id, current transaction client, or mutable per-request caches on singleton instances.

## Migration Workflow Rule

When persisted schema changes, update the surrounding layers in the same change set.

Typical order:

1. schema change
2. generated client or adapter regeneration
3. repository mapping update
4. DTO or contract update
5. use case update
6. route or API client update
7. tests and seed data update

Do not stop after the schema file compiles.
