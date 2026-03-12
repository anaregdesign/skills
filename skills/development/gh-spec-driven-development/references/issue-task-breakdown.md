# Issue Task Breakdown

Use this reference when turning a development request into GitHub Issue checkboxes.

## Goal

Break the work into the shortest meaningful steps that can be reviewed, reasoned about, and checked off as they finish.

## Good Task-List Characteristics

- Each checkbox represents one meaningful delivery step.
- Each step has one clear reason to exist.
- Each step is small enough to review without scanning an entire feature rewrite.
- Each step is large enough to matter on its own.
- Together, the steps describe the whole delivery path from spec to merge.

## Good Examples

- `[ ] Write or update /doc/spec/<name>.md`
- `[ ] Add or update the route or API surface for the new behavior`
- `[ ] Implement the server or domain behavior`
- `[ ] Implement the UI flow or visible states`
- `[ ] Add tests and run verification`
- `[ ] Update PR summary and merge`

## Bad Examples

- `[ ] Implement feature`
- `[ ] Fix code`
- `[ ] Finalize everything`
- `[ ] Rename variable`
- `[ ] Think about edge cases`

## Practical Guidance

- Keep the checklist in delivery order.
- Start with the spec if the request is new or underdefined.
- Keep the final checklist item tied to verification or merge readiness.
- If the work grows, edit the Issue and split the checkbox list rather than hiding extra work in commits.
- If one checkbox stops being meaningful, replace it with smaller meaningful steps.

## Completion Rule

- Check a box only when the corresponding step is actually done.
- Remove or rewrite obsolete checkboxes instead of leaving misleading stale tasks behind.
- Before merge, make sure the remaining unchecked items truly represent unfinished work.
