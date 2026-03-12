# Plan Execution Workflow

Use this reference when executing the active plan for a development request.

## 1. Create or Update `/doc/plan.md`

- Create `/doc/plan.md` after the spec is clear enough to guide implementation.
- Keep the spec link near the top of the plan.
- Use only the planning horizons the work actually needs.
- Treat `/doc/plan.md` as temporary execution state, not as durable documentation.

Example shape:

```md
# Execution Plan

## Links
- Spec: /doc/spec/feature-name.md

## Short-Term
- [ ] Implement the first reviewed slice
- [ ] Run verification
```

## 2. Keep the Plan Current During Execution

- Check off plan tasks as they finish.
- Update `/doc/plan.md` when work moves between `Long-Term`, `Mid-Term`, and `Short-Term`.
- Revise `/doc/plan.md` when technical findings change dependencies, sequencing, or slice boundaries.
- Record progress in coherent commit units that match the current execution slice.
- Update the spec when accepted user-visible behavior changes.
- Keep the plan small enough to stay legible.

## 3. Finish and Clean Up

- Confirm all meaningful plan checkboxes are complete.
- Delete `/doc/plan.md` once there is no remaining tracked work.
- Keep the durable behavior description in `/doc/spec/`, not in the deleted plan file.
- If additional follow-up work remains after the current execution slice finishes, replace the old plan with a new current plan instead of keeping stale completed history.
