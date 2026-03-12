---
name: spec-driven-workflow
description: "Own the spec-first planning workflow for feature or behavior work. Use when the work needs user-visible requirements under `/doc/spec/`, a temporary execution plan in `/doc/plan.md`, ordered hierarchical sections using `Section`, `Subsection`, and optional `Sub-subsection` headings as needed, checkbox maintenance during implementation, and cleanup of the temporary plan file once all tracked work is done. Do not use this skill to decide app-code architecture or cloud platform topology."
---

# Spec Driven Workflow

## Overview

Use this skill to turn a development request into a spec-first, plan-driven workflow. Capture the user-visible requirement in `/doc/spec/` first, then create a temporary execution tracker in `/doc/plan.md` and keep the spec and plan synchronized until implementation is complete.
Keep the requirements document focused on what the user sees, needs, and accepts. Keep `/doc/plan.md` focused on execution state, sequencing, and checkbox progress. Delete `/doc/plan.md` once every tracked checkbox is complete so only durable project documents remain.
If the incoming request is overly detailed or repetitive, propose a higher-level goal framing, show the preserved constraints, and ask the instruction giver to review that reframing before you drive the spec and plan from it.
This skill owns planning artifacts and shared commit-log workflow, not app architecture or cloud platform rules. Pair it with the relevant coding or hosting skill after the spec and execution path are clear.

## Quick Start

1. Read [`references/spec-documentation.md`](references/spec-documentation.md) before writing or updating `/doc/spec/`.
2. Read [`references/plan-documentation.md`](references/plan-documentation.md) before creating or rewriting `/doc/plan.md`.
3. Read [`references/commit-history-guidance.md`](references/commit-history-guidance.md) before recording shared commit history.
4. Read [`references/plan-execution-workflow.md`](references/plan-execution-workflow.md) before executing the plan.
5. For a new development request:
   - if `/doc/spec/` is empty or the relevant spec does not exist yet, start by creating the initial user-facing spec under `/doc/spec/`
   - if the incoming instruction is overly fine-grained, propose a higher-level goal framing and ask the instruction giver to review it before drafting the spec and plan
   - create or update the temporary execution tracker in `/doc/plan.md`
   - choose only the hierarchy levels the work needs: a single `Section` for simple work, add `Subsection` for grouped reviewable slices, and add `Sub-subsection` only when a subsection still needs a deeper ordered breakdown
6. During implementation:
   - keep `/doc/plan.md` checkboxes current
   - record changes in deliberate, reviewable commit units
   - revise the plan when technical findings change the execution path, sequencing, or slice boundaries
   - update the spec and plan if accepted behavior or execution sequence changes
7. At completion:
   - confirm all plan checkboxes are done or intentionally removed
   - delete `/doc/plan.md`

## Non-Negotiable Rules

- Document the user-visible requirement under `/doc/spec/` before substantial implementation begins.
- If `/doc/spec/` has no relevant document for the request yet, create the initial spec before creating the main implementation.
- Create or update `/doc/plan.md` before substantial implementation so execution is tracked in one place.
- Keep `/doc/plan.md` temporary. Delete it when all tracked checkboxes are complete and no execution tracking is still needed.
- When incoming instructions are overly fine-grained or repetitive, propose a higher-level goal that preserves the user's intent and ask the instruction giver to review it before adopting it.
- Preserve hard constraints, acceptance criteria, and externally required sequencing, but do not mirror incidental micromanagement step by step.
- Structure `/doc/plan.md` as an ordered hierarchy only to the extent the work needs it:
  - use a single `Section` for simple, directly executable work
  - add `Subsection` when a section spans several reviewable slices
  - add `Sub-subsection` only when a subsection still needs a deeper ordered breakdown
- Break work into the smallest meaningful reviewable steps and record them as checkboxes under the lowest useful heading.
- Update checkboxes as work completes. Do not leave finished steps unchecked.
- Remove or rewrite stale plan items when the work changes. Do not preserve obsolete steps just for history.
- Revise `/doc/plan.md` when implementation reveals a better technical path. Do not force execution to follow an outdated plan.
- Keep shared commit history in Conventional Commits format when the repository uses it.
- Prefer one logical, reviewable work unit per commit when practical.
- Split behavior changes, refactors, docs, tests, and dependency updates into separate commits when they represent different reasons to change, but do not force tiny broken commits.
- Keep the spec and plan aligned. Do not let one artifact tell a different story from the other.
- Do not turn `/doc/plan.md` into a permanent history log. When the work is done, delete it.

## Workflow

### 1. Capture the request in `/doc/spec`

- Create `/doc/spec/` if it does not exist.
- If `/doc/spec/` exists but does not yet contain a relevant document for the request, start by creating the initial spec file.
- Use a clear filename that ties back to the work item, typically with a stable slug.
- Capture the request as a user-facing requirement document before writing the main implementation.
- If the request arrives as repeated micro-instructions, show a higher-level goal framing around the user goal, visible outcome, and real constraints, then ask the instruction giver to confirm it before you rely on it.
- Link the spec to `/doc/plan.md` while the temporary plan exists.

### 2. Create or update `/doc/plan.md`

- Create `/doc/` if it does not exist.
- Use `/doc/plan.md` as the temporary execution tracker for the current delivery unit.
- Start with only the hierarchy levels that the work actually needs.
- Keep the lowest active heading immediately executable.
- Add `Subsection` only when several reviewable slices need grouping.
- Add `Sub-subsection` only when a subsection still needs another ordered layer.
- Once the reframed goal is reviewed, plan against that higher-level goal rather than every repeated instruction line.
- Keep plan items about delivery steps, not vague aspirations.

### 3. Implement and keep the workflow current

- Complete work one meaningful slice at a time.
- Check off the matching plan checkbox as each slice is finished.
- Update `/doc/plan.md` if work is reordered, split, or moved between `Section`, `Subsection`, and `Sub-subsection` blocks.
- Revise `/doc/plan.md` when technical review or implementation findings change dependencies, sequencing, or slice boundaries.
- Record progress in coherent commits that match the current execution slice.
- Update the spec when accepted behavior changes.
- Keep the active plan small enough to stay useful.

### 4. Finish cleanly

- Confirm every plan checkbox is complete or intentionally removed.
- Delete `/doc/plan.md` once there is no remaining tracked work.
- Keep the durable behavior description in `/doc/spec/`, not in the deleted plan file.

## References

- spec-writing guidance: [`references/spec-documentation.md`](references/spec-documentation.md)
- `/doc/plan.md` hierarchical structure and checkbox guidance: [`references/plan-documentation.md`](references/plan-documentation.md)
- commit history and Conventional Commits guidance: [`references/commit-history-guidance.md`](references/commit-history-guidance.md)
- plan execution and cleanup workflow: [`references/plan-execution-workflow.md`](references/plan-execution-workflow.md)
