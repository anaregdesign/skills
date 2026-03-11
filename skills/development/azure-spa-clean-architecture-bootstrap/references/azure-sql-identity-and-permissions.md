# Azure SQL Identity And Permissions

Use this reference when the app needs Azure SQL Database, `Managed Identity` access, or distinct runtime and migration permissions.

## Prefer This Azure SQL Pattern

- Set a Microsoft Entra admin on the Azure SQL logical server.
- Create database users from external provider identities.
- Grant runtime identities only the least privilege they need.
- Reserve elevated roles for migration or break-glass identities.

## Keep Runtime and Migration Permissions Separate

- Runtime app Managed Identity: prefer `db_datareader` and `db_datawriter`
- Migration identity: add only the elevated roles needed for controlled schema change workflows
- Avoid giving the web runtime identity ownership-style or DDL-heavy privileges

## Keep SQL Server and Prisma Boundaries Honest

- Keep Prisma imports inside server infrastructure.
- Keep repository interfaces in `domain`.
- Keep transport DTOs and session shapes outside `domain`.
- Treat SQL Server provider changes, native-type tuning, and migration regeneration as real migration work, not as a trivial config flip.

## Verification

- Verify the deployed runtime Managed Identity can reach Azure SQL and only the intended database roles are granted.
- Verify runtime and migration identities stay separate in docs, IaC, and operational runbooks.
