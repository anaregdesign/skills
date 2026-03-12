# Plan Documentation

Use this reference when creating or updating `/doc/plan.md` for a development request.

## Goal

Turn the request into a temporary execution tracker that can be executed from top to bottom, keeps related work grouped, and can be deleted cleanly once the work is done.

## Hierarchical Model

- `Section`: the top-level execution block or phase
- `Subsection`: a grouped reviewable slice inside a section
- `Sub-subsection`: an optional deeper ordered breakdown when a subsection still spans several concrete steps

Use only the levels the work actually needs.

- Simple work may use a single `Section` only.
- Medium-complexity work may use `Section` and `Subsection`.
- Add `Sub-subsection` only when another ordered layer makes execution clearer.

## Recommended Structure

```md
# Execution Plan

## Links
- Spec: /doc/spec/<name>.md

## Section 1 - <phase or workstream>
### Subsection 1.1 - <reviewable slice>
- [ ] <next actionable step>
- [ ] <next actionable step>

#### Sub-subsection 1.1.1 - <optional deeper breakdown>
- [ ] <concrete step>
- [ ] <concrete step>
```

## Good Plan Characteristics

- The top-down order makes the next execution slice obvious.
- Each heading has a descriptive title, not just a number.
- Each checkbox represents one meaningful delivery step.
- The plan stays small enough to review and rewrite.
- The hierarchy reflects actual work shape, not ceremony.
- The lowest active heading contains the items that can be executed now.

## Good Examples

- `## Section 1 - Bootstrap`
  - `[ ] Write or update /doc/spec/<name>.md`
- `### Subsection 1.1 - First reviewed slice`
  - `[ ] Add or update the route or API surface for the new behavior`
  - `[ ] Implement the UI or server slice`
- `#### Sub-subsection 1.1.1 - Verification`
  - `[ ] Run verification and update the plan`

## Bad Examples

- A large top-level section with no actionable lowest-level checklist when the next steps are already known
- Generic headings such as `## Section 1` with no descriptive title
- Checkboxes such as `[ ] Implement feature` or `[ ] Finalize everything`
- Leaving completed work unchecked
- Keeping obsolete sections or tasks after the work changes

## Practical Guidance

- Start with one `Section` unless the work clearly needs more structure.
- Add `Subsection` only when it helps group several reviewable slices.
- Add `Sub-subsection` only when another level materially improves clarity.
- If the incoming request is over-specified, propose the farthest stable goal you think captures it and ask the instruction giver to review that framing before shaping the plan tree.
- Order `Section`, `Subsection`, and `Sub-subsection` blocks in the sequence they should be executed.
- Keep the next executable lowest-level block near the top of the remaining plan.
- Preserve true constraints and required sequencing, but do not turn every repeated instruction into its own checkbox.
- Rewrite the plan when the execution path changes instead of appending stale history.
- If technical investigation reveals a better execution path, revise the plan to match the current best approach instead of preserving the original guess.
- Update the spec only when accepted user-visible behavior changes; technical replanning by itself belongs in `/doc/plan.md`.

## Completion Rule

- Check a box only when the corresponding step is actually done.
- Remove or rewrite obsolete checkboxes instead of leaving misleading stale tasks behind.
- When all remaining checkboxes are complete and no tracked execution work remains, delete `/doc/plan.md`.
