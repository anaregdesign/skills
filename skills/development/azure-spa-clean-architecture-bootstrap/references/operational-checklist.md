# Operational Checklist

Use this reference before release, after deployment, or when handing work back to the user.

## At Project Start

- Confirm which Azure tenant, subscription, and resource scopes are definitely required.
- Confirm which RBAC assignments are definitely required for developers, runtime identities, migration identities, and deploy identities.
- Confirm whether Azure SQL Microsoft Entra admin setup is required.
- Confirm whether GitHub Actions OIDC setup is enough or whether an unavoidable Service Principal is still required.
- Ask for those prerequisites early so they do not block implementation or release work later.

## Before Push

- Run targeted tests for touched features.
- Run typecheck, lint, and production build.
- Review architecture boundaries and forbidden imports.
- Validate workflow syntax and infrastructure files.
- Confirm the app no longer depends on `.env` or `.env.example` for Azure runtime behavior.
- If local development uses SQLite, confirm no Azure-hosted config, scripts, or docs still point at SQLite.

## Before Release

- Confirm README matches the current architecture and deployment model.
- Confirm screenshots and callback URLs are current.
- Confirm GitHub Environment variables and Azure-side identities exist.
- Confirm App Configuration keys and Key Vault secrets match the runtime config contract.
- When the app requires user authentication, confirm the documented local sign-in path still works with the intended dev or test identities.
- Confirm the hosted environment uses Azure SQL Database rather than SQLite.
- Confirm migrations and critical persistence flows were validated against Azure SQL Database, not only against local SQLite.
- Confirm the release workflow deploys the immutable release tag, not `latest`.

## After Release

- Check the GitHub Release URL.
- Check the Actions run URL.
- Check the deployed app URL and the `/health` endpoint.
- Confirm the intended Azure revision became healthy.

## After Infrastructure Changes

- Note any partial or failed resources that still need cleanup.
- Note any manual Azure portal or app-registration changes that the user must complete.
- Note any RBAC assignments that were added and their scope.
- Note any App Configuration keys, Key Vault secrets, or callback URLs that still need to be set by the user.

## Handoff

- Report what was changed.
- Report what was verified.
- Report what remains blocked or unverified.
- Report the exact file paths or workflow names that matter for future maintenance.
