# Commit History Guidance

Use this reference when turning plan progress into shared commit history.

## Goal

Keep commit history easy to review, easy to understand, and easy to revert while the work moves through the active plan.

## Format

- Use Conventional Commits for commit titles when the repository uses them.
- Prefer `<type>: <summary>` and add a scope only when it improves traceability.
- Common types:
  - `feat` for user-facing capability changes
  - `fix` for bug fixes
  - `docs` for documentation-only changes
  - `refactor` for structure cleanup without behavior change
  - `test` for test-focused changes
  - `chore` for maintenance or dependency work

## Granularity

- Prefer one logical, reviewable work unit per commit.
- Keep each commit internally coherent.
- Split behavior changes from refactors when the split is real and reviewable.
- Split docs, tests, and dependency changes from behavior changes when they represent distinct reasons to change.
- Do not force tiny broken commits just to satisfy granularity.

## Relationship To The Plan

- Let the current `Short-Term` slice suggest the next commit boundary.
- If one plan checkbox expands into several meaningful review units, use multiple commits and keep the plan wording broad enough to allow that.
- If several tiny edits only make sense together, keep them in one commit even when they belong to the same plan checkbox.
- Do not use commit history as a replacement for `/doc/plan.md`; the plan tracks current execution, while commits record completed review units.

## Quality Check

Before creating a commit, confirm:

- Would a reviewer understand why this commit exists?
- Does it mix unrelated reasons to change?
- Would reverting it be reasonably safe?
- Does the title match the actual kind of change?
