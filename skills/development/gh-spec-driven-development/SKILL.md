---
name: gh-spec-driven-development
description: Drive spec-first GitHub development workflow for product or feature work. Use when a user asks to implement a feature, change behavior, or start development in a GitHub-backed repository and you need to document complete user-visible requirements under `/doc/spec`, create or update a GitHub Issue, create a working branch named with a Conventional-Commits-aligned prefix such as `feat/`, `fix/`, `docs/`, or `refactor/`, open a draft PR early, break the work into the smallest meaningful steps as issue task-list checkboxes, keep those checkboxes updated as work finishes, and complete the flow by merging the PR, closing the issue, and deleting the branch.
---

# Gh Spec Driven Development

## Overview

Use this skill to turn a development request into a spec-first GitHub workflow. Capture the user-visible requirement in `/doc/spec/` first, then keep the spec, Issue, branch, PR, and final cleanup synchronized until the work is merged.
Keep the requirements document focused on what the user sees, needs, and accepts. Keep the GitHub artifacts focused on execution state, reviewability, and closure.

## Quick Start

1. Read [`references/spec-documentation.md`](references/spec-documentation.md) before writing or updating `/doc/spec/`.
2. Read [`references/issue-task-breakdown.md`](references/issue-task-breakdown.md) before drafting the Issue checklist.
3. Read [`references/github-ops-workflow.md`](references/github-ops-workflow.md) before creating the Issue, branch, and PR.
4. For a new development request:
   - create or update the user-facing spec under `/doc/spec/`
   - create or update the GitHub Issue with a task-list checklist
   - create a semantic working branch linked to that Issue
   - open a draft PR early once the branch has the initial meaningful commit
5. During implementation:
   - keep the Issue checklist current
   - keep the PR description linked to the spec and Issue
   - update the spec if accepted behavior changes
6. At completion:
   - confirm all checklist items are done
   - merge the PR
   - confirm the Issue is closed
   - delete the working branch

## Non-Negotiable Rules

- Document the user-visible requirement under `/doc/spec/` before substantial implementation begins.
- Write the spec from the user's point of view first: goals, scope, behavior, acceptance criteria, edge cases, and non-goals. Keep implementation details secondary.
- Create or update one GitHub Issue per coherent development request unless the repository already has an explicit different tracking model.
- Break work into the smallest meaningful reviewable steps and record them as GitHub Issue task-list checkboxes.
- Update checkboxes as work completes. Do not leave finished steps unchecked.
- Use semantic branch prefixes aligned with the work type, preferably `feat/`, `fix/`, `docs/`, `refactor/`, `chore/`, or `test/`.
- Open a draft PR early so the work has a review surface before the final merge.
- Keep the spec, Issue, branch, PR, and final merged state aligned. Do not let one artifact tell a different story from the others.
- Merge only after the checklist is complete, the PR reflects the final change, and required verification has passed.
- After merge, close or confirm closure of the Issue and delete the working branch.
- If the repository has stronger branch protection, PR review, merge strategy, or naming rules, follow those rules while preserving this workflow's intent.

## Workflow

### 1. Capture the request in `/doc/spec`

- Create `/doc/spec/` if it does not exist.
- Use a clear filename that ties back to the work item, typically with an Issue number or stable slug.
- Capture the request as a user-facing requirement document before writing the main implementation.
- Link the spec to the Issue and PR once those artifacts exist.

### 2. Open or update the GitHub Issue

- Use the Issue as the execution hub for the change.
- Include the spec link near the top.
- Include a task-list checklist that reflects the shortest meaningful implementation slices.
- Keep the checklist about delivery steps, not vague aspirations.

### 3. Create the working branch

- Branch from the repository's normal base branch unless the repo requires another starting point.
- Prefer a branch name aligned with the intended Conventional Commit type, such as `feat/<issue-number>-<slug>` or `fix/<issue-number>-<slug>` when the Issue number is known.
- Keep one branch focused on one coherent Issue whenever practical.

### 4. Open the PR early

- Push the branch once the initial meaningful commit exists, typically the spec and workflow setup or the first reviewed slice.
- Open a draft PR early rather than waiting for the entire feature to be complete.
- Link the PR to the Issue and spec.
- Use an automatic closing keyword only when the PR truly resolves the Issue.

### 5. Implement and keep the workflow current

- Complete work one meaningful slice at a time.
- Check off the matching Issue checkbox as each slice is finished.
- Update the PR description and spec if scope or accepted behavior changes.
- Keep commits reviewable and aligned with the checklist.

### 6. Finish cleanly

- Confirm every checklist item is complete or intentionally removed.
- Confirm the PR summary matches the delivered behavior.
- Merge the PR with the repository's preferred strategy.
- Confirm the Issue closes.
- Delete the remote branch and clean up the local branch.

## References

- spec-writing guidance: [`references/spec-documentation.md`](references/spec-documentation.md)
- task-list breakdown guidance: [`references/issue-task-breakdown.md`](references/issue-task-breakdown.md)
- GitHub Issue, branch, PR, merge, and cleanup workflow: [`references/github-ops-workflow.md`](references/github-ops-workflow.md)
