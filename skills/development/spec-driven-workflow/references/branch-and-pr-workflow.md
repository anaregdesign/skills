# Branch And PR Workflow

Use this reference when executing the branch, PR, merge, and cleanup flow for a development request.

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

## 2. Create the Branch

- Branch from the repository's normal base branch.
- Prefer a semantic prefix aligned with the intended Conventional Commit type.
- Default prefixes:
  - `feat/` for user-facing capability work
  - `fix/` for bug fixes
  - `docs/` for documentation-only work
  - `refactor/` for structure cleanup without behavior change
  - `chore/` for maintenance work
  - `test/` for test-focused changes
- Prefer `<type>/<slug>` using the spec filename or another short stable work slug.
- If the same delivery unit already has an active branch, continue on it instead of creating another branch.
- If the repository already standardizes on a different semantic branch vocabulary such as `feature/`, follow the repository convention.

Example:

```bash
git switch main
git pull --ff-only
git switch -c feat/feature-name
```

## 3. Open or Update the PR Early

- Push the branch once the initial meaningful commit exists.
- Open a draft PR early rather than waiting for the whole feature to be complete.
- If a draft PR already exists for the branch, update it instead of opening a duplicate PR.
- Link the spec and current plan in the PR body while the plan exists.

Example:

```bash
git push -u origin feat/feature-name
gh pr create --draft --title "feat: implement feature name" --body-file .github/PULL_REQUEST_TEMPLATE.md
```

If the repository does not have a PR template, write a short PR body that includes:

- spec link
- current plan link while `/doc/plan.md` exists
- summary of completed slices
- verification notes

## 4. Keep Plan and PR Updated During Execution

- Check off plan tasks as they finish.
- Update `/doc/plan.md` when work moves between `Long-Term`, `Mid-Term`, and `Short-Term`.
- Update the PR body if scope, behavior, or verification changes.
- Update the spec when accepted user-visible behavior changes.
- Keep commit messages aligned with the repository convention. Prefer Conventional Commits when the repository uses them.
- Keep commits aligned with the current plan.

## 5. Merge and Clean Up

- Confirm all meaningful plan checkboxes are complete.
- Delete `/doc/plan.md` once there is no remaining tracked work.
- Confirm the PR summary still stands on its own after the plan file is deleted.
- Confirm required verification and review expectations are satisfied.
- Merge with the repository's preferred strategy.
- Delete the remote branch when repository policy allows.
- Delete the local branch after switching away from it.

Common cleanup commands:

```bash
gh pr merge <pr-number> --delete-branch
git switch main
git pull --ff-only
git branch -d feat/feature-name
```

## 6. Keep Repo Rules Above Default Flow

- If the repository requires a different base branch, PR template, merge strategy, or review rule, follow the repository.
- Preserve the core behavior of this skill even when the exact commands differ:
  - spec first
  - temporary plan file
  - semantic working branch aligned to the work type
  - early PR
  - plan checkboxes updated during work
  - plan deletion, merge, and branch cleanup at the end
