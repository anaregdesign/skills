# GitHub Ops Workflow

Use this reference when executing the GitHub Issue, branch, PR, merge, and cleanup flow for a development request.

## 1. Create or Update the Issue

- Create a GitHub Issue for the work if one does not already exist.
- If an open Issue already tracks the same coherent request, update it rather than creating a duplicate.
- Keep the title short and user-meaningful.
- Link the `/doc/spec/` document near the top.
- Add the task-list checklist in the Issue body.

Example shape:

```md
## Spec
- /doc/spec/123-feature-name.md

## Tasks
- [ ] Write or update the spec
- [ ] Implement the backend behavior
- [ ] Implement the UI behavior
- [ ] Verify and prepare merge
```

## 2. Create the Branch

- Branch from the repository's normal base branch.
- Prefer a semantic prefix aligned with the intended Conventional Commit type.
- If the Issue already has an active branch for the same delivery unit, continue on it instead of creating another branch.
- Default prefixes:
  - `feat/` for user-facing capability work
  - `fix/` for bug fixes
  - `docs/` for documentation-only work
  - `refactor/` for structure cleanup without behavior change
  - `chore/` for maintenance work
  - `test/` for test-focused changes
- Prefer `<type>/<issue-number>-<slug>` when the Issue number is available.
- If the repository already standardizes on a different semantic branch vocabulary such as `feature/`, follow the repository convention.

Example:

```bash
git switch main
git pull --ff-only
git switch -c feat/123-feature-name
```

## 3. Open or Update the PR Early

- Push the branch once the initial meaningful commit exists.
- Open a draft PR early rather than waiting for the whole feature to be complete.
- If a draft PR already exists for the branch, update it instead of opening a duplicate PR.
- Link the Issue and spec in the PR body.
- Use a closing keyword like `Closes #123` only when the PR is intended to fully resolve the Issue.

Example:

```bash
git push -u origin feat/123-feature-name
gh pr create --draft --title "feat: implement feature name" --body-file .github/PULL_REQUEST_TEMPLATE.md
```

If the repository does not have a PR template, write a short PR body that includes:

- spec link
- Issue link
- checklist or summary of slices completed
- verification notes

## 4. Keep Issue and PR Updated During Execution

- Check off Issue tasks as they finish.
- Update the PR body if scope, behavior, or verification changes.
- Update the spec when accepted user-visible behavior changes.
- Keep commit messages aligned with the repository convention. Prefer Conventional Commits when the repository uses them.
- Keep commits aligned with the work shown in the Issue.

## 5. Merge and Close Cleanly

- Confirm all meaningful Issue checkboxes are complete.
- Confirm required verification and review expectations are satisfied.
- Merge with the repository's preferred strategy.
- Confirm the Issue closes, either automatically or explicitly.
- Delete the remote branch when repository policy allows.
- Delete the local branch after switching away from it.

Common cleanup commands:

```bash
gh pr merge <pr-number> --delete-branch
git switch main
git pull --ff-only
git branch -d feat/123-feature-name
```

## 6. Keep Repo Rules Above Default Flow

- If the repository requires a different base branch, PR template, merge strategy, or review rule, follow the repository.
- Preserve the core behavior of this skill even when the exact commands differ:
  - spec first
  - Issue task list
  - semantic working branch aligned to the work type
  - early PR
  - checkboxes updated during work
  - merge, close, and branch cleanup at the end
