# Plan Documentation

Use this reference when creating or updating `/doc/plan.md` for a development request.

## Goal

Turn the request into a temporary execution tracker that makes the next work visible, keeps larger phases legible, and can be deleted cleanly once the work is done.

## Horizon Model

- `Short-Term`: immediately actionable steps for the next execution slice
- `Mid-Term`: a grouping layer for several related short-term slices
- `Long-Term`: larger phases, dependencies, or intentionally staged follow-up

Use only the horizons the work actually needs.

- Simple work may use `Short-Term` only.
- Medium-complexity work may use `Mid-Term` and `Short-Term`.
- Use `Long-Term` only when the work genuinely spans larger phases or deferred subgoals.

## Recommended Structure

```md
# Execution Plan

## Links
- Spec: /doc/spec/<name>.md

## Long-Term
- [ ] <optional larger phase>

## Mid-Term
- [ ] <optional grouped slice>

## Short-Term
- [ ] <next actionable step>
- [ ] <next actionable step>
```

## Good Plan Characteristics

- The plan makes the next execution slice obvious.
- Each checkbox represents one meaningful delivery step.
- The plan stays small enough to review and rewrite.
- The hierarchy reflects actual work shape, not ceremony.
- `Short-Term` contains the items that can be executed now.

## Good Examples

- `## Short-Term`
  - `[ ] Write or update /doc/spec/<name>.md`
  - `[ ] Add or update the route or API surface for the new behavior`
  - `[ ] Implement the UI or server slice`
  - `[ ] Run verification and update the plan`
- `## Mid-Term`
  - `[ ] Complete the first end-to-end reviewed slice`
  - `[ ] Complete the remaining supporting slice`
- `## Long-Term`
  - `[ ] Finish the current delivery phase`

## Bad Examples

- A `Long-Term` section with no actionable `Short-Term` work when the next steps are already known
- Checkboxes such as `[ ] Implement feature` or `[ ] Finalize everything`
- Leaving completed work unchecked
- Keeping obsolete horizons or tasks after the work changes

## Practical Guidance

- Start with `Short-Term` unless the work clearly needs more structure.
- Add `Mid-Term` only when it helps group several reviewable slices.
- Add `Long-Term` only when the current work intentionally spans larger phases.
- Move work downward as it becomes actionable rather than duplicating the same task in every horizon.
- Rewrite the plan when the execution path changes instead of appending stale history.
- If technical investigation reveals a better execution path, revise the plan to match the current best approach instead of preserving the original guess.
- Update the spec only when accepted user-visible behavior changes; technical replanning by itself belongs in `/doc/plan.md`.

## Completion Rule

- Check a box only when the corresponding step is actually done.
- Remove or rewrite obsolete checkboxes instead of leaving misleading stale tasks behind.
- When all remaining checkboxes are complete and no tracked execution work remains, delete `/doc/plan.md`.
