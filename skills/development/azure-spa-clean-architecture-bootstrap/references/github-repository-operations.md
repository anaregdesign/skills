# GitHub Repository Operations

Use this reference when creating or hardening the target GitHub repository for Azure delivery.

## Repository Bootstrap

- Create the repository before wiring release automation.
- Prefer an organization-owned repository for production workloads.
- Keep the default branch name explicit and consistent across workflow docs.
- Add a short repository description that matches the deployed system, not just the framework stack.

## Minimum Repository Structure

- `README.md`
- `.gitignore`
- `.github/workflows/`
- `azure.yaml`
- `infra/`
- `scripts/azure/`

## Default Branch Governance

- Protect the default branch.
- Require pull requests unless the team intentionally works trunk-only.
- Require status checks for test, typecheck, build, and any deploy-gating workflow.
- Restrict force pushes and branch deletion on the default branch.
- Prefer linear history or squash merge consistently; do not mix merge policies without a reason.

## GitHub Environments

- Create a `production` Environment for release deploys.
- Store deployment IDs and non-secret config as Environment variables, not as repo-wide secrets.
- Store only actual secrets as Environment secrets.
- Prefer Azure App Configuration and Key Vault as the runtime config stores rather than expanding GitHub-hosted variables into an `.env`-style runtime source of truth.
- Add protection rules when production deploys should require approval.
- Keep the OIDC federated credential subject aligned with the repository and Environment name.

## Recommended Environment Variables

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_RESOURCE_GROUP`
- `AZURE_CONTAINER_APP_NAME`

## Optional Environment Secrets

- `GHCR_PULL_TOKEN` only if the package must stay private
- Provider secrets that cannot be replaced by platform identity

## GHCR Package Policy

- Prefer public GHCR packages for public apps when there is no security or licensing reason to hide the image.
- If the image must be private, document why and add the minimum registry pull credentials needed by the runtime platform.
- Keep package naming aligned with `ghcr.io/<owner>/<repo>` unless there is a deliberate multi-image strategy.

## Release Policy

- Trigger production image publish from `release.published`.
- Deploy only from immutable release tags.
- Use a new patch release to fix a broken workflow definition instead of mutating an older release.
- Keep prerelease handling explicit. Either skip production deploys for prereleases or send them to a separate Environment.

## OIDC and Azure Access

- Prefer GitHub Actions OIDC over Azure client secrets.
- Scope the federated credential subject to the exact repository and Environment.
- Give the deploy identity only the Azure role scope it needs.
- Keep runtime Managed Identity separate from the deploy identity.

## Repository Hygiene

- Keep README deployment instructions current.
- Keep screenshots and public URLs current when user-facing behavior changed.
- Keep configuration contract docs synchronized with App Configuration keys, Key Vault secret names, and runtime config parsing.
- Keep workflow files validated with `actionlint`.

## Optional Governance Files

- Add `CODEOWNERS` when review ownership matters.
- Add issue and pull request templates when the team needs consistent change intake.
- Add Dependabot or Renovate only when the team will actually triage update noise.
- Add a security policy if the repository is public and externally consumed.

## Handoff Checklist

- Report the repository URL.
- Report the default branch.
- Report which GitHub Environments were created.
- Report which Variables and Secrets were populated.
- Report which required checks or branch protections still need manual setup.
