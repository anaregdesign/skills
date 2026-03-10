# Azure Platform Bootstrap

Use this reference when the app needs Azure hosting, Azure-managed secrets, or production-grade deployment primitives.

## Clean Architecture First

Platform choices are subordinate to Clean Architecture. If a hosting shortcut, deployment habit, or managed-service default would weaken boundaries or ownership, keep the architecture intact and change the integration instead.

## Default Platform Choices

- Use Azure Container Apps for React Router apps that need a server runtime.
- Use Azure SQL Database serverless for relational persistence unless workload characteristics force another SKU.
- Use Key Vault for runtime secrets and secret rotation.
- Use Application Insights and Log Analytics for telemetry and diagnostics.
- Use Managed Identity for app runtime access to Azure resources.
- Use GitHub Actions OIDC for deployment access to Azure.

## Treat "SPA" Correctly

- Keep a static-only SPA only when the app has no server-owned secrets, no OAuth callback handling, and no server-side persistence boundary.
- Switch to React Router framework runtime when social login, server sessions, Prisma, Azure SQL, or server-owned API calls appear.
- Preserve SPA-style navigation and presentational component boundaries even when the deployment target is a containerized web app.

## Add the Expected Repository Files

- Add `Dockerfile` for the production image.
- Add `azure.yaml` for app and infra orchestration.
- Add `infra/` for Bicep or Terraform.
- Add `scripts/azure/` for idempotent provisioning or post-provision helpers.
- Add `app/routes/health.ts` for cheap health checks.
- Add `.env.example` and keep it free of real secrets.

## Prefer This Azure Topology

- Container Apps environment
- Container App for the web runtime
- Azure SQL logical server plus serverless database
- Key Vault
- Application Insights
- Log Analytics workspace
- Optional ACR only when GHCR is not acceptable or private-network requirements force Azure-native image storage

## Correct Common Mistakes

- Do not keep SQLite as the production store when the app needs shared history, multi-user competition, or cloud failover.
- Do not inject Azure secrets directly into the repo or into long-lived GitHub secrets if OIDC or Managed Identity can replace them.
- Do not hide migration execution inside container startup unless the blast radius is understood and rollback is trivial.
- Do not skip a health endpoint. Container Apps deploy and smoke-test flow should have a stable probe target.
- Do not leave callback URLs undocumented. Each environment needs explicit OAuth redirect values.

## Keep IaC and Runtime Boundaries Explicit

- Keep Azure resource definitions declarative in `infra/`.
- Keep runtime configuration parsing in server infrastructure code.
- Keep provisioning scripts thin and repeatable.
- Keep one place for naming rules, region selection, and environment conventions.

## Minimum Verification

- Validate the infra plan before deploy.
- Build the container image locally or in CI.
- Verify the health route responds after deploy.
- Verify the app can reach its backing services with production auth mode.
