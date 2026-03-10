---
name: azure-spa-clean-architecture-bootstrap
description: Bootstrap and enforce clean architecture for Vite-powered React Router + Prisma v7 web apps that must ship on Azure with GitHub-based delivery. Use when creating or evolving a React Router SPA-style app with server-backed auth or persistence, adding Azure Container Apps or Azure SQL, wiring Managed Identity or DefaultAzureCredential, configuring GitHub Releases, GHCR, and GitHub Actions OIDC, or preparing CI/CD, release, and deployment workflows.
---

# Azure Spa Clean Architecture Bootstrap

## Overview

Use this skill to keep the clean-architecture discipline of a React Router app while standardizing Azure hosting, identity, and GitHub operations. Preserve SPA-style navigation, but switch to a server runtime whenever OAuth callbacks, Prisma, server-only secrets, or Azure SQL access make a static-only SPA the wrong abstraction.

## Quick Start

1. Choose the runtime mode first:
   - Keep pure SPA mode only when the app has no server-only secrets, no social login callback, no Prisma-backed mutations, and no protected server endpoints.
   - Use React Router framework runtime when the app needs auth callbacks, cookies, Prisma, Azure SQL, or server-owned secrets.
2. Read the base architecture references from the sibling skill:
   - project bootstrap: [`../enforce-react-spa-architecture/references/project-bootstrap.md`](../enforce-react-spa-architecture/references/project-bootstrap.md)
   - layout and dependency rules: [`../enforce-react-spa-architecture/references/layout-and-dependency-rules.md`](../enforce-react-spa-architecture/references/layout-and-dependency-rules.md)
   - FlatRoute REST API rules: [`../enforce-react-spa-architecture/references/flat-route-rest-api-guidelines.md`](../enforce-react-spa-architecture/references/flat-route-rest-api-guidelines.md)
   - Prisma boundary rules: [`../enforce-react-spa-architecture/references/prisma-boundary-rules.md`](../enforce-react-spa-architecture/references/prisma-boundary-rules.md)
   - view-state and handler patterns: [`../enforce-react-spa-architecture/references/view-state-and-handler-patterns.md`](../enforce-react-spa-architecture/references/view-state-and-handler-patterns.md)
   - stateful flow compromises: [`../enforce-react-spa-architecture/references/stateful-flow-compromises.md`](../enforce-react-spa-architecture/references/stateful-flow-compromises.md)
   - hotspot refactor workflow: [`../enforce-react-spa-architecture/references/hotspot-refactor-workflow.md`](../enforce-react-spa-architecture/references/hotspot-refactor-workflow.md)
   - verification gates: [`../enforce-react-spa-architecture/references/verification-gates.md`](../enforce-react-spa-architecture/references/verification-gates.md)
3. Read the Azure and GitHub references in this skill:
   - Azure platform bootstrap: [`references/azure-platform-bootstrap.md`](references/azure-platform-bootstrap.md)
   - Azure identity and SQL: [`references/azure-identity-and-sql.md`](references/azure-identity-and-sql.md)
   - GitHub release delivery: [`references/github-release-delivery.md`](references/github-release-delivery.md)
   - template adoption guide: [`references/template-assets.md`](references/template-assets.md)
   - operational checklist: [`references/operational-checklist.md`](references/operational-checklist.md)
4. Classify the change:
   - route or UI composition
   - auth or session boundary
   - persistence or migration
   - Azure infrastructure
   - GitHub workflow or release automation
   - production verification

## Repository Additions

- Put Azure IaC in `infra/`.
- Put deployment and bootstrap helpers in `scripts/azure/`.
- Put CI and release automation in `.github/workflows/`.
- Keep Azure project wiring in `azure.yaml`.
- Keep container packaging in `Dockerfile`.
- Keep environment documentation in `.env.example`.
- Add a cheap health probe in `app/routes/health.ts`.

## Template Assets

- Use the generic repo templates in `assets/templates/`.
- Replace placeholder tokens such as `__APP_NAME__`, `__SERVICE_NAME__`, and `__PUBLIC_APP_URL__` only after the target app's naming rules are clear.
- Keep the template vocabulary generic. Do not leak app-specific names, resource-group names, or domain nouns back into the shared asset files.
- Start from these templates when bootstrapping:
  - `assets/templates/azure.yaml`
  - `assets/templates/Dockerfile`
  - `assets/templates/.env.example`
  - `assets/templates/app/routes/health.ts`
  - `assets/templates/.github/workflows/release-container-image.yml`
  - `assets/templates/scripts/azure/postprovision.sh`
  - `assets/templates/infra/main.bicep`

## Non-Negotiable Rules

- Keep all dependency and placement rules from `enforce-react-spa-architecture`.
- Keep `app/routes` thin even when a server runtime is enabled.
- Keep `app/components` presentational and keep async orchestration in `app/lib/client/usecase/`.
- Keep Prisma and Azure SDK imports inside server infrastructure or deployment code.
- Treat "SPA" as a UX target, not as a requirement to remove the server runtime.
- Prefer React Router framework runtime over bolting ad hoc APIs onto a static bundle when auth, persistence, or secret-backed integrations need a server.
- Prefer Azure Container Apps for apps that need a server runtime. Use Static Web Apps only for truly static frontends.
- Prefer Azure SQL Database serverless for relational persistence. Treat SQLite as local-dev or prototype storage only.
- Use `DefaultAzureCredential` or Managed Identity only where runtime SDK support is real. Do not assume Prisma CLI or schema migration flows inherit that auth automatically.
- Separate runtime identity from migration or admin identity.
- Use GitHub Actions OIDC to Azure. Do not store Azure client secrets in GitHub.
- Deploy immutable release-tag images, not mutable `latest`.
- Keep production values in GitHub Environments and Azure-managed secret stores rather than in repo files.
- Add explicit health endpoints and post-deploy smoke tests.
- Keep README, callback URLs, env-var documentation, release notes, and IaC in sync with the deployed system.

## Implementation Workflow

### 0. Choose the correct runtime contract

- Keep pure SPA mode only for fully static frontends.
- Enable server runtime before writing features that need OAuth callbacks, cookies, Prisma, secrets, or server-owned data access.
- Keep route modules responsible for HTTP wiring, loader or action composition, and top-level dependency assembly only.

### 1. Bootstrap the app and architecture

- Follow the sibling architecture references before adding cloud features.
- Start with `create-react-router`, Vite, FlatRoute conventions, and Prisma v7.
- Keep components presentational and move async orchestration into `app/lib/client/usecase/`.
- Keep domain, use case, repository port, and infrastructure ownership explicit from the first feature.

### 2. Add cloud-facing repository structure intentionally

- Put Azure IaC in `infra/`.
- Put deployment and provisioning scripts in `scripts/azure/`.
- Put GitHub release and deploy workflows in `.github/workflows/`.
- Keep environment parsing explicit and centralized in server infrastructure.
- Keep app-specific scripts idempotent and safe to re-run.

### 3. Add auth and session boundaries at the edge

- Handle social login callbacks, cookies, and session state at the route or server edge.
- Keep authorization decisions in use cases or domain policies.
- Keep provider profile DTOs out of `domain` until a stable internal model is necessary.
- Document environment-specific callback URLs in README and app registration notes.

### 4. Add persistence and identity intentionally

- Put repository ports in `app/lib/domain/repositories/`.
- Implement Azure SQL or SQL Server access in `app/lib/server/infrastructure/repositories/`.
- Use Managed Identity or `DefaultAzureCredential` for runtime access when the driver path supports it.
- Keep migrations explicit and separate from app startup.
- Keep `db_datareader` and `db_datawriter` on runtime identities. Reserve elevated roles for migration or admin identities.

### 5. Prepare Azure deployment

- Add a container-friendly `Dockerfile`.
- Add `azure.yaml` and declarative infrastructure.
- Prefer Container Apps, Managed Identity, Key Vault, Application Insights, and Azure SQL serverless as the default platform set.
- Add `/health` and keep probes cheap.
- Keep resource naming, region choice, and scope boundaries deliberate.

### 6. Prepare GitHub delivery

- Build and publish the container image on `release.published`.
- Deploy only after image publish succeeds.
- Use GitHub Environment protection for production.
- Keep OIDC federation subject scoped to the repository and environment.
- Use GHCR by default unless the platform requires ACR.

### 7. Verify before push and before release

- Run tests, typecheck, lint, and build.
- Review boundary drift and forbidden imports.
- Validate workflow syntax and IaC before release.
- Smoke-test the deployed revision and confirm callback URLs, health checks, and DB connectivity.

### 8. Operate and hand off cleanly

- Update README with architecture, Azure topology, required variables, callback URLs, and release flow.
- Record what is verified versus what still needs cloud-side confirmation.
- Avoid leaving partial infrastructure, stale releases, or unmanaged identities without noting the follow-up work.

## Placement Guide

- Need core React Router clean-architecture rules: use the sibling `../enforce-react-spa-architecture/` references.
- Need Azure IaC: `infra/`
- Need Azure deployment scripts: `scripts/azure/`
- Need GitHub release and deploy workflows: `.github/workflows/`
- Need health probes: `app/routes/health.ts`
- Need server config parsing: `app/lib/server/infrastructure/`
- Need Azure SQL or SDK adapters: `app/lib/server/infrastructure/repositories/` and `app/lib/server/infrastructure/gateways/`
- Need production env documentation: `.env.example` and `README.md`

## References

- base architecture bootstrap: [`../enforce-react-spa-architecture/references/project-bootstrap.md`](../enforce-react-spa-architecture/references/project-bootstrap.md)
- base dependency rules: [`../enforce-react-spa-architecture/references/layout-and-dependency-rules.md`](../enforce-react-spa-architecture/references/layout-and-dependency-rules.md)
- base FlatRoute REST rules: [`../enforce-react-spa-architecture/references/flat-route-rest-api-guidelines.md`](../enforce-react-spa-architecture/references/flat-route-rest-api-guidelines.md)
- base Prisma boundary rules: [`../enforce-react-spa-architecture/references/prisma-boundary-rules.md`](../enforce-react-spa-architecture/references/prisma-boundary-rules.md)
- base view-state patterns: [`../enforce-react-spa-architecture/references/view-state-and-handler-patterns.md`](../enforce-react-spa-architecture/references/view-state-and-handler-patterns.md)
- base stateful-flow compromises: [`../enforce-react-spa-architecture/references/stateful-flow-compromises.md`](../enforce-react-spa-architecture/references/stateful-flow-compromises.md)
- base hotspot refactor workflow: [`../enforce-react-spa-architecture/references/hotspot-refactor-workflow.md`](../enforce-react-spa-architecture/references/hotspot-refactor-workflow.md)
- base verification gates: [`../enforce-react-spa-architecture/references/verification-gates.md`](../enforce-react-spa-architecture/references/verification-gates.md)
- Azure platform bootstrap: [`references/azure-platform-bootstrap.md`](references/azure-platform-bootstrap.md)
- Azure identity and SQL: [`references/azure-identity-and-sql.md`](references/azure-identity-and-sql.md)
- GitHub release delivery: [`references/github-release-delivery.md`](references/github-release-delivery.md)
- template adoption guide: [`references/template-assets.md`](references/template-assets.md)
- operational checklist: [`references/operational-checklist.md`](references/operational-checklist.md)
