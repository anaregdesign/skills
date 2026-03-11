# Layout And Module Placement

## Canonical Layout

```text
app/
  routes/
  components/
    shared/
  lib/
    client/
      usecase/
        <feature>/
          use-<feature>.ts
          state.ts
          reducer.ts
          selectors.ts
          handlers.ts
      infrastructure/
        api/
        browser/
    server/
      usecase/
      infrastructure/
        config/
        repositories/
        gateways/
    domain/
      entities/
      value-objects/
      policies/
      services/
      repositories/
```

Use these directories by responsibility, not by team preference or historical drift.

## State Module Placement

For non-trivial client interaction flows, create a feature directory under `app/lib/client/usecase/` and colocate the state modules there.

Preferred shape:

```text
app/lib/client/usecase/thread-composer/
  use-thread-composer.ts
  state.ts
  reducer.ts
  selectors.ts
  handlers.ts
  types.ts
```

Use these files by responsibility:

- `state.ts`: state shape and initial state
- `reducer.ts`: reducer function and action definitions
- `selectors.ts`: derived read models and computed flags
- `handlers.ts`: event-to-dispatch mapping or async command helpers
- `use-<feature>.ts`: public Hook or controller entry point

Do not create horizontal buckets such as `app/state/`, `app/reducers/`, `app/stores/`, `app/handlers/`, or `app/lib/client/usecase/state/`.

## No Generic Common Bucket

Do not add a catch-all common directory.

Prefer this order instead:

1. Keep code with the route, use case, or domain module that owns it.
2. Duplicate a tiny utility once if the reuse pattern is still uncertain.
3. Extract only after the abstraction is clearly stable.

## Feature Public API Rule

Treat each feature directory as having a public entry point and private internals.

Prefer:

- `client/usecase/<feature>/use-<feature>.ts` as the public client entry
- `server/usecase/<feature>/index.ts` or one primary use-case module as the public server entry

Avoid importing another feature's private files such as `reducer.ts`, `selectors.ts`, `handlers.ts`, or `state.ts`.

## Circular Dependency Rule

Treat import cycles as architecture violations, especially inside feature internals.

Common bad cycles:

- `selectors -> handlers -> reducer -> selectors`
- `route -> usecase -> route`
- `infrastructure -> usecase -> infrastructure`

When a cycle appears:

1. move shared pure logic to a lower-level leaf module
2. invert the dependency through an interface or parameter
3. merge modules back together if the split was artificial

## TS And TSX Naming Rule

Keep file names explicit enough that responsibility is visible before opening the file.

Use these defaults:

- route modules: follow FlatRoute naming, such as `api.orders.ts`, `api.orders.$orderId.ts`, or `settings.profile.tsx`
- React component files: `PascalCase.tsx`
- non-component modules: responsibility-based `kebab-case.ts`

For component files:

- make the primary exported component name match the file name
- use `.tsx` only when the file renders JSX
- keep feature views near their owning feature until they prove to be generic

Inside a feature directory, short file names such as `state.ts`, `reducer.ts`, `selectors.ts`, `handlers.ts`, and `types.ts` are acceptable because the directory already provides the feature context.

Avoid vague file names such as `helpers.ts`, `utils.ts`, `common.ts`, `misc.ts`, `temp.ts`, or `new.ts`.

Use `index.ts` only when it is a deliberate public entry point.

## Typical Flow

For a form submission:

1. A route module renders a container page.
2. A client use case Hook owns the draft state and handlers.
3. A presentational component renders fields and calls passed handlers.
4. A client infrastructure API client sends the request or a route action handles it.
5. A server use case applies the business rule.
6. A server infrastructure repository persists via Prisma.

Each step should only depend on the next layer inward or on an adapter explicitly created for that boundary.
