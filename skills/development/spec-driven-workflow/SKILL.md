---
name: spec-driven-workflow
description: "Own the spec-first planning and delivery workflow for feature or behavior work in branch-and-PR repositories. Use when the work needs user-visible requirements under `/doc/spec/`, a temporary execution plan in `/doc/plan.md`, horizon-based checklists using `Long-Term`, `Mid-Term`, and `Short-Term` sections as needed, semantic branch naming such as `feat/`, `fix/`, `docs/`, or `refactor/`, early draft PR creation, plan maintenance during implementation, merge readiness checks, and cleanup of the temporary plan file and working branch. Do not use this skill to decide app-code architecture, UI boundaries, or cloud platform topology."
---

# Spec Driven Workflow

## Overview

Use this skill to turn a development request into a spec-first, plan-driven workflow. Capture the user-visible requirement in `/doc/spec/` first, then create a temporary execution tracker in `/doc/plan.md` and keep the spec, plan, branch, and PR synchronized until the work is merged.
Keep the requirements document focused on what the user sees, needs, and accepts. Keep `/doc/plan.md` focused on execution state, sequencing, and checkbox progress. Delete `/doc/plan.md` once every tracked checkbox is complete so only durable project documents remain.
This skill owns planning and repository workflow artifacts, not app architecture or cloud platform rules. Pair it with the relevant coding or hosting skill after the spec and execution path are clear.

## Quick Start

1. Read [`references/spec-documentation.md`](references/spec-documentation.md) before writing or updating `/doc/spec/`.
2. Read [`references/plan-documentation.md`](references/plan-documentation.md) before creating or rewriting `/doc/plan.md`.
3. Read [`references/branch-and-pr-workflow.md`](references/branch-and-pr-workflow.md) before creating the branch or PR.
4. For a new development request:
   - if `/doc/spec/` is empty or the relevant spec does not exist yet, start by creating the initial user-facing spec under `/doc/spec/`
   - create or update the temporary execution tracker in `/doc/plan.md`
   - choose only the planning horizons the work needs: `Short-Term` for simple work, `Mid-Term` plus `Short-Term` for multi-slice work, and `Long-Term` only when the work genuinely spans larger phases
   - create a semantic working branch for the delivery unit, or continue on the existing active branch if it already tracks the same work
   - open a draft PR early once the branch has the initial meaningful commit, or update the existing draft PR if one already tracks the work
5. During implementation:
   - keep `/doc/plan.md` checkboxes current
   - keep the PR description linked to the spec and current plan while the plan exists
   - update the spec and plan if accepted behavior or execution sequence changes
6. At completion:
   - confirm all plan checkboxes are done or intentionally removed
   - delete `/doc/plan.md`
   - merge the PR
   - delete the working branch when repository policy allows

## Non-Negotiable Rules

- Document the user-visible requirement under `/doc/spec/` before substantial implementation begins.
- If `/doc/spec/` has no relevant document for the request yet, create the initial spec before creating the main implementation.
- Create or update `/doc/plan.md` before substantial implementation so execution is tracked in one place.
- Keep `/doc/plan.md` temporary. Delete it when all tracked checkboxes are complete and no execution tracking is still needed.
- Structure `/doc/plan.md` by planning horizon only to the extent the work needs it:
  - use `Short-Term` only for simple, directly executable work
  - add `Mid-Term` when the work spans several reviewable slices
  - add `Long-Term` only when the work genuinely spans larger phases, dependencies, or deferred subgoals
- Break work into the smallest meaningful reviewable steps and record them as checkboxes under the lowest useful horizon.
- Update checkboxes as work completes. Do not leave finished steps unchecked.
- Remove or rewrite stale plan items when the work changes. Do not preserve obsolete steps just for history.
- Use semantic branch prefixes aligned with the work type, preferably `feat/`, `fix/`, `docs/`, `refactor/`, `chore/`, or `test/`.
- Open a draft PR early so the work has a review surface before the final merge.
- Keep commit history reviewable and follow the repository's commit convention. Prefer Conventional Commits where the repository uses them.
- Keep the spec, plan, branch, PR, and final merged state aligned. Do not let one artifact tell a different story from the others.
- Merge only after the plan is complete, the PR reflects the final change, and required verification has passed.
- If the repository has stronger branch protection, PR review, merge strategy, or naming rules, follow those rules while preserving this workflow's intent.

## Workflow

### 1. Capture the request in `/doc/spec`

- Create `/doc/spec/` if it does not exist.
- If `/doc/spec/` exists but does not yet contain a relevant document for the request, start by creating the initial spec file.
- Use a clear filename that ties back to the work item, typically with a stable slug.
- Capture the request as a user-facing requirement document before writing the main implementation.
- Link the spec to `/doc/plan.md` and the PR once those artifacts exist.

### 2. Create or update `/doc/plan.md`

- Create `/doc/` if it does not exist.
- Use `/doc/plan.md` as the temporary execution tracker for the current delivery unit.
- Start with only the planning horizons that the work actually needs.
- Keep `Short-Term` actionable and immediately executable.
- Add `Mid-Term` only when several short-term slices need grouping.
- Add `Long-Term` only when the work spans larger phases or intentionally staged follow-up.
- Keep plan items about delivery steps, not vague aspirations.

### 3. Create or continue on the working branch

- Branch from the repository's normal base branch unless the repo requires another starting point.
- Prefer a branch name aligned with the intended Conventional Commit type, such as `feat/<slug>` or `fix/<slug>`.
- If the same delivery unit already has an active working branch, continue on it unless the work has intentionally been split.
- Keep one branch focused on one coherent delivery unit whenever practical.

### 4. Open or update the PR early

- Push the branch once the initial meaningful commit exists, typically the spec and plan setup or the first reviewed slice.
- Open a draft PR early rather than waiting for the entire feature to be complete.
- If a draft PR already exists for the branch, update it instead of opening a duplicate PR.
- Link the PR to the spec and, while it exists, `/doc/plan.md`.
- Before final merge, make sure the PR summary still stands on its own after `/doc/plan.md` is deleted.

### 5. Implement and keep the workflow current

- Complete work one meaningful slice at a time.
- Check off the matching plan checkbox as each slice is finished.
- Update `/doc/plan.md` if work moves between `Long-Term`, `Mid-Term`, and `Short-Term` horizons.
- Update the PR description and spec if scope or accepted behavior changes.
- Keep commit messages aligned with the repository convention. Prefer Conventional Commits when the repository uses them.
- Keep commits reviewable and aligned with the current plan.

### 6. Finish cleanly

- Confirm every plan checkbox is complete or intentionally removed.
- Delete `/doc/plan.md` once there is no remaining tracked work.
- Confirm the PR summary matches the delivered behavior and does not depend on the deleted plan file.
- Merge the PR with the repository's preferred strategy.
- Delete the remote branch when repository policy allows, and clean up the local branch.

## References

- spec-writing guidance: [`references/spec-documentation.md`](references/spec-documentation.md)
- `/doc/plan.md` horizon structure and checkbox guidance: [`references/plan-documentation.md`](references/plan-documentation.md)
- branch, PR, merge, and cleanup workflow: [`references/branch-and-pr-workflow.md`](references/branch-and-pr-workflow.md)
