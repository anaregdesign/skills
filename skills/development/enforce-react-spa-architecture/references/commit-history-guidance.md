# Commit History Guidance

## Goal

Keep shared history easy to review, revert, and reason about.

## Commit Format

Use the Conventional Commits 1.0.0 title format for commits that will remain in shared history:

```text
<type>[optional scope]: <description>
```

Examples:

- `feat(profile): add account summary chart`
- `fix(auth): prevent redirect loop after refresh`
- `refactor(profile-editor): move reducer into usecase directory`
- `docs(skill): clarify chart accessibility guidance`
- `test(profile-editor): cover reducer transitions`
- `chore(deps): upgrade @fluentui/react-components`

Use `!` or a `BREAKING CHANGE:` footer when the change is intentionally breaking.

## Recommended Types

- `feat`: new user-facing or developer-facing capability
- `fix`: behavior correction
- `refactor`: structure change without intended behavior change
- `docs`: documentation-only change
- `test`: test-only change
- `perf`: performance improvement
- `build`: build system or dependency packaging change
- `ci`: CI or workflow change
- `chore`: maintenance that does not fit the categories above
- `revert`: explicit revert of an earlier commit

## Granularity Rules

- Prefer one logical reason to change per commit.
- Separate behavior changes from refactors when the split is real and understandable.
- Separate dependency upgrades, generated-file refreshes, or formatting-only churn from feature or bug-fix commits when practical.
- Do not combine unrelated feature work in one commit just because it was edited in the same session.
- Do not force tiny commits that knowingly leave the tree broken if a cleaner coherent commit is possible.

## Scope Guidance

Use `scope` when it improves traceability. Good scopes usually match a feature, layer, package, or workflow:

- `profile`
- `billing`
- `auth`
- `routes`
- `domain`
- `usecase`
- `prisma`
- `ci`
- `skill`

Avoid vague scopes like `misc` or `update`.

## Reviewability Standard

A good commit should usually be:

- understandable without reading unrelated commits
- revertable without surprising collateral damage
- internally coherent in both code and message
- validated enough for its slice, ideally with the relevant tests or checks run

If one commit message needs the word "and" because it truly contains multiple reasons to change, it may need to be split.
