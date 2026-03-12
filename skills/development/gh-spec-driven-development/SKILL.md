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
   - if `/doc/spec/` is empty or the relevant spec does not exist yet, start by creating the initial user-facing spec under `/doc/spec/`
   - otherwise update the existing relevant spec under `/doc/spec/`
   - create or update the GitHub Issue with a task-list checklist
   - create a semantic working branch linked to that Issue, or continue on the existing active branch for that Issue
   - open a draft PR early once the branch has the initial meaningful commit, or update the existing draft PR if one already tracks the work
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
- If `/doc/spec/` has no relevant document for the request yet, create the initial spec before creating the main implementation.
- Write the spec from the user's point of view first: goals, scope, behavior, acceptance criteria, edge cases, and non-goals. Keep implementation details secondary.
- Create or update one GitHub Issue per coherent development request unless the repository already has an explicit different tracking model.
- If the same delivery unit already has an open Issue, active branch, or draft PR, update those artifacts instead of creating duplicates.
- Break work into the smallest meaningful reviewable steps and record them as GitHub Issue task-list checkboxes.
- Update checkboxes as work completes. Do not leave finished steps unchecked.
- Use semantic branch prefixes aligned with the work type, preferably `feat/`, `fix/`, `docs/`, `refactor/`, `chore/`, or `test/`.
- Open a draft PR early so the work has a review surface before the final merge.
- Keep commit history reviewable and follow the repository's commit convention. Prefer Conventional Commits where the repository uses them.
- Keep the spec, Issue, branch, PR, and final merged state aligned. Do not let one artifact tell a different story from the others.
- Merge only after the checklist is complete, the PR reflects the final change, and required verification has passed.
- After merge, close or confirm closure of the Issue and delete the working branch when repository policy allows.
- If the repository has stronger branch protection, PR review, merge strategy, or naming rules, follow those rules while preserving this workflow's intent.

## Workflow

### 1. Capture the request in `/doc/spec`

- Create `/doc/spec/` if it does not exist.
- If `/doc/spec/` exists but does not yet contain a relevant document for the request, start by creating the initial spec file.
- Use a clear filename that ties back to the work item, typically with an Issue number or stable slug.
- Capture the request as a user-facing requirement document before writing the main implementation.
- Link the spec to the Issue and PR once those artifacts exist.

### 2. Open or update the GitHub Issue

- Use the Issue as the execution hub for the change.
- If an open Issue already tracks the same coherent request, update it instead of creating a duplicate.
- Include the spec link near the top.
- Include a task-list checklist that reflects the shortest meaningful implementation slices.
- Keep the checklist about delivery steps, not vague aspirations.

### 3. Create or continue on the working branch

- Branch from the repository's normal base branch unless the repo requires another starting point.
- Prefer a branch name aligned with the intended Conventional Commit type, such as `feat/<issue-number>-<slug>` or `fix/<issue-number>-<slug>` when the Issue number is known.
- If the Issue already has an active working branch for the same delivery unit, continue on it unless the work has intentionally been split.
- Keep one branch focused on one coherent Issue whenever practical.

### 4. Open or update the PR early

- Push the branch once the initial meaningful commit exists, typically the spec and workflow setup or the first reviewed slice.
- Open a draft PR early rather than waiting for the entire feature to be complete.
- If a draft PR already exists for the branch, update it instead of opening a duplicate PR.
- Link the PR to the Issue and spec.
- Use an automatic closing keyword only when the PR truly resolves the Issue.

### 5. Implement and keep the workflow current

- Complete work one meaningful slice at a time.
- Check off the matching Issue checkbox as each slice is finished.
- Update the PR description and spec if scope or accepted behavior changes.
- Keep commit messages aligned with the repository convention. Prefer Conventional Commits when the repository uses them.
- Keep commits reviewable and aligned with the checklist.

### 6. Finish cleanly

- Confirm every checklist item is complete or intentionally removed.
- Confirm the PR summary matches the delivered behavior.
- Merge the PR with the repository's preferred strategy.
- Confirm the Issue closes.
- Delete the remote branch when repository policy allows, and clean up the local branch.

## References

- spec-writing guidance: [`references/spec-documentation.md`](references/spec-documentation.md)
- task-list breakdown guidance: [`references/issue-task-breakdown.md`](references/issue-task-breakdown.md)
- GitHub Issue, branch, PR, merge, and cleanup workflow: [`references/github-ops-workflow.md`](references/github-ops-workflow.md)
