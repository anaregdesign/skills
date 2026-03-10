# Azure Identity And SQL

Use this reference when the app needs Azure workload identity, Azure SQL, or social login backed by server-side persistence.

## Separate the Identity Types

- Keep end-user social login separate from Azure workload identity.
- Use a GitHub Actions federated identity for deployment only.
- Use a Container App Managed Identity for runtime access to Azure resources.
- Use a separate migration or admin identity for schema changes and elevated SQL work.

## Use DefaultAzureCredential Carefully

- Use `DefaultAzureCredential` for runtime paths when the SDK or driver actually supports token-based auth.
- Do not assume Prisma CLI, migration tooling, or every SQL driver can use the same auth path automatically.
- If runtime auth works with Managed Identity but migration tooling needs a different connection path, document the split explicitly instead of hiding it.

## Prefer This Azure SQL Pattern

- Set a Microsoft Entra admin on the Azure SQL logical server.
- Create database users from external provider identities.
- Grant runtime identities only the least privilege they need.
- Reserve elevated roles for migration or break-glass identities.

## Keep Runtime and Migration Permissions Separate

- Runtime app identity: prefer `db_datareader` and `db_datawriter`
- Migration identity: add only the elevated roles needed for controlled schema change workflows
- Avoid giving the web runtime identity ownership-style or DDL-heavy privileges

## Handle Social Login at the Server Edge

- Keep OAuth callback handling in routes or server entry points.
- Keep provider tokens, session cookies, and refresh behavior outside `domain`.
- Map provider profile DTOs into stable internal user shapes only at the application boundary.
- Document callback URLs for local, staging, and production environments.

## Keep SQL Server and Prisma Boundaries Honest

- Keep Prisma imports inside server infrastructure.
- Keep repository interfaces in `domain`.
- Keep transport DTOs and session shapes outside `domain`.
- Treat SQL Server provider changes, native-type tuning, and migration regeneration as real migration work, not as a trivial config flip.

## Environment and Config Guidance

- Keep app-facing config parsing centralized.
- Keep `.env.example` descriptive but secret-free.
- Keep Azure identity IDs, DB host names, and callback URLs documented in README or deployment notes.
- Keep GitHub Environment values separate from Azure runtime secrets.

## Verification

- Verify the deploy identity can update the Azure hosting resource and nothing broader than necessary.
- Verify the runtime identity can reach Azure SQL and only the intended database roles are granted.
- Verify local development still has a sane fallback path when Managed Identity is unavailable.
