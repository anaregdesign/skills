---
name: azure-spa-clean-architecture-bootstrap
description: Add Azure hosting, identity, secretless config, and GitHub delivery guidance on top of enforce-react-spa-architecture for Vite-powered React Router + Prisma v7 web apps. This skill extends enforce-react-spa-architecture and should be installed with it. Use when creating or evolving a React Router SPA-style app that must ship on Azure, adding Microsoft Entra ID authentication or Azure CLI app registration when authentication is required, adding Azure Container Apps or Azure SQL, wiring Managed Identity or DefaultAzureCredential, configuring GitHub Releases, GHCR, and GitHub Actions OIDC, or preparing CI/CD, release, and deployment workflows.
---

# Azure Spa Clean Architecture Bootstrap

## Overview

Use this skill to layer Azure hosting, identity, and GitHub delivery decisions onto the base React Router clean architecture owned by `enforce-react-spa-architecture`. Preserve SPA-style navigation, but switch to a server runtime whenever OAuth callbacks, Prisma, server-only secrets, or Azure SQL access make a static-only SPA the wrong abstraction.
This skill owns Azure platform, `Microsoft Entra ID`, secretless config, IaC, and release workflow guidance. Keep code structure, UI guardrails, commit hygiene, and general verification rules in the companion skill, and repeat them here only when they are critical to protect Azure-specific boundaries.
Treat requests for "Microsoft auth" as `Microsoft Entra ID` only when the app actually needs user authentication. If the app does not need auth, skip the app registration and auth guidance.
Prefer a secretless configuration model: do not introduce `.env` or `.env.example` for Azure-hosted apps. Put non-secret runtime configuration in Azure App Configuration, put secrets in Key Vault, use local `DefaultAzureCredential` during development, and use `ManagedIdentityCredential` for deployed app-to-Azure and Azure SQL authentication.
When the app requires user authentication, prefer a real local sign-in path with a dev or test `Microsoft Entra ID` registration and test identities rather than a hidden development auth bypass.

## Companion Skill Requirement

- Install `enforce-react-spa-architecture` together with this skill. Do not use this skill as a standalone replacement for the base architecture skill.
- If the companion skill is missing, install it before continuing from [https://github.com/anaregdesign/skills/tree/main/skills/development/enforce-react-spa-architecture](https://github.com/anaregdesign/skills/tree/main/skills/development/enforce-react-spa-architecture).
- Prefer `$skill-installer` for the install step when another Codex instance needs to fetch the published skill from GitHub.
- Continue only after the sibling references under `../enforce-react-spa-architecture/references/` are locally available.

## Quick Start

1. Choose the runtime mode first:
   - Keep pure SPA mode only when the app has no server-only secrets, no social login callback, no Prisma-backed mutations, and no protected server endpoints.
   - Use React Router framework runtime when the app needs auth callbacks, cookies, Prisma, Azure SQL, or server-owned secrets.
2. Confirm the companion skill is installed:
   - required skill: `enforce-react-spa-architecture`
   - published URL: `https://github.com/anaregdesign/skills/tree/main/skills/development/enforce-react-spa-architecture`
   - if missing, install it with `$skill-installer` before reading the sibling references
3. Read the base architecture references from the sibling skill:
   - project bootstrap: [`../enforce-react-spa-architecture/references/project-bootstrap.md`](../enforce-react-spa-architecture/references/project-bootstrap.md)
   - layout and module placement: [`../enforce-react-spa-architecture/references/layout-and-module-placement.md`](../enforce-react-spa-architecture/references/layout-and-module-placement.md)
   - client layer responsibilities: [`../enforce-react-spa-architecture/references/client-layer-responsibilities.md`](../enforce-react-spa-architecture/references/client-layer-responsibilities.md)
   - server and domain layer responsibilities: [`../enforce-react-spa-architecture/references/server-and-domain-layer-responsibilities.md`](../enforce-react-spa-architecture/references/server-and-domain-layer-responsibilities.md)
   - boundary and contract rules: [`../enforce-react-spa-architecture/references/boundary-and-contract-rules.md`](../enforce-react-spa-architecture/references/boundary-and-contract-rules.md)
   - FlatRoute REST API rules: [`../enforce-react-spa-architecture/references/flat-route-rest-api-guidelines.md`](../enforce-react-spa-architecture/references/flat-route-rest-api-guidelines.md)
   - Prisma boundary rules: [`../enforce-react-spa-architecture/references/prisma-boundary-rules.md`](../enforce-react-spa-architecture/references/prisma-boundary-rules.md)
   - verification gates: [`../enforce-react-spa-architecture/references/verification-gates.md`](../enforce-react-spa-architecture/references/verification-gates.md)
4. Read the Azure and GitHub references in this skill:
   - Azure platform bootstrap: [`references/azure-platform-bootstrap.md`](references/azure-platform-bootstrap.md)
   - Azure identity overview index: [`references/azure-identity-and-sql.md`](references/azure-identity-and-sql.md)
   - user auth, runtime contract, and local sign-in path: [`references/entra-user-auth-and-runtime-contracts.md`](references/entra-user-auth-and-runtime-contracts.md)
   - Azure CLI and `az rest` app registration flow: [`references/entra-app-registration-cli.md`](references/entra-app-registration-cli.md)
   - workload identity and secretless config: [`references/azure-workload-identity-and-secretless-config.md`](references/azure-workload-identity-and-secretless-config.md)
   - Azure SQL identity and permissions: [`references/azure-sql-identity-and-permissions.md`](references/azure-sql-identity-and-permissions.md)
   - GitHub repository operations: [`references/github-repository-operations.md`](references/github-repository-operations.md)
   - GitHub release delivery: [`references/github-release-delivery.md`](references/github-release-delivery.md)
   - template adoption guide: [`references/template-assets.md`](references/template-assets.md)
   - operational checklist: [`references/operational-checklist.md`](references/operational-checklist.md)
5. Classify the change:
   - route or UI composition
   - Microsoft Entra ID auth or app registration when authentication is required
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
- Keep secretless config bootstrap and parsing in `app/lib/server/infrastructure/config/` or the narrowest equivalent server config module.
- Keep configuration contract documentation in `README.md`.
- Add a cheap health probe in `app/routes/health.ts`.

## Template Assets

- Use the generic repo templates in `assets/templates/`.
- Replace placeholder tokens such as `__APP_NAME__`, `__SERVICE_NAME__`, and `__PUBLIC_APP_URL__` only after the target app's naming rules are clear.
- Keep the template vocabulary generic. Do not leak app-specific names, resource-group names, or domain nouns back into the shared asset files.
- Start from these templates when bootstrapping:
  - `assets/templates/azure.yaml`
  - `assets/templates/Dockerfile`
  - `assets/templates/app/routes/health.ts`
  - `assets/templates/.github/workflows/release-container-image.yml`
  - `assets/templates/scripts/azure/postprovision.sh`
  - `assets/templates/infra/main.bicep`

## Non-Negotiable Rules

- Install and keep `enforce-react-spa-architecture` available together with this skill.
- Keep all dependency, placement, UI, commit, and verification rules from `enforce-react-spa-architecture`.
- Do not redefine the companion skill's general coding guardrails here. Use this skill for Azure, identity, infrastructure, and delivery deltas, and repeat code-level rules only when they protect those deltas.
- Keep Prisma and Azure SDK imports inside server infrastructure or deployment code.
- Treat "SPA" as a UX target, not as a requirement to remove the server runtime.
- Prefer React Router framework runtime over bolting ad hoc APIs onto a static bundle when auth, persistence, or secret-backed integrations need a server.
- Prefer Azure Container Apps for apps that need a server runtime. Use Static Web Apps only for truly static frontends.
- Prefer Azure SQL Database serverless for relational persistence when the app needs shared relational data. Treat SQLite as local-dev or prototype storage only.
- When authentication is required, prefer `Microsoft Entra ID` over portal-only or ad hoc "Microsoft auth" descriptions, and keep the chosen `signInAudience` explicit.
- Do not use `.env` or `.env.example` for Azure runtime configuration. Use Azure App Configuration for non-secret settings and Key Vault for secrets.
- Use local `DefaultAzureCredential` during development after `az login` or `azd auth login`.
- Use `ManagedIdentityCredential` for deployed app-to-Azure and Azure SQL authentication. Do not rely on a broad `DefaultAzureCredential` chain in production.
- Use `DefaultAzureCredential` or Managed Identity only where runtime SDK support is real. Do not assume Prisma CLI or schema migration flows inherit that auth automatically.
- Separate runtime identity from migration or admin identity.
- When the app requires user authentication, prefer a separate dev or test app registration from the production registration, and use a separate test tenant when production-tenant policies or risk make safe testing hard.
- Keep localhost redirect URIs in the dev or test registration, or document clearly why they still exist in another registration. Remove unnecessary development redirect URIs from the production registration.
- Use test users, test groups, or invited guest users to complete local sign-in flows. If testing inside the production tenant, restrict the test enterprise application to specific users or groups.
- Do not treat a hidden local auth bypass as the standard development path for an app that requires authentication.
- Prefer scripted `az` or `az rest` app registration changes over portal-only click paths so redirect URIs, audience, and secret mode stay reproducible.
- Use GitHub Actions OIDC to Azure. Do not store Azure client secrets in GitHub.
- Keep repository governance explicit: protected default branch, required checks, and production Environment scoping.
- Deploy immutable release-tag images, not mutable `latest`.
- Keep production values in GitHub Environments and Azure-managed secret stores rather than in repo files.
- Add explicit health endpoints and post-deploy smoke tests.
- Keep README, callback URLs, configuration contract docs, release notes, and IaC in sync with the deployed system.

## Implementation Workflow

### 0. Choose the correct runtime contract

- Keep pure SPA mode only for fully static frontends.
- Enable server runtime before writing features that need OAuth callbacks, cookies, Prisma, secrets, or server-owned data access.
- Keep route modules responsible for HTTP wiring, loader or action composition, and top-level dependency assembly only.

### 1. Bootstrap the app and architecture

- Confirm `enforce-react-spa-architecture` is installed from the published GitHub path before relying on sibling references.
- Follow the sibling architecture references before adding cloud features.
- Keep this skill focused on platform deltas after the companion skill has established code structure, UI rules, and verification gates.

### 2. Add cloud-facing repository structure intentionally

- Put Azure IaC in `infra/`.
- Put deployment and provisioning scripts in `scripts/azure/`.
- Put GitHub release and deploy workflows in `.github/workflows/`.
- Keep secretless bootstrap config and runtime parsing explicit and centralized in server infrastructure.
- Keep one clear bootstrap path for Azure App Configuration and Key Vault instead of scattering fallback `.env` reads.
- Keep app-specific scripts idempotent and safe to re-run.

### 3. Add auth and session boundaries at the edge when authentication is required

- Handle social login callbacks, cookies, and session state at the route or server edge.
- Only enter this step when the app actually needs authentication.
- When the app needs Microsoft auth, decide early whether the runtime contract is `web` or `spa`.
- Prefer `web` platform redirect URIs and server-owned cookie sessions when React Router framework runtime already exists for Prisma, secrets, or protected server endpoints.
- Use `spa` platform redirect URIs and browser PKCE only when the frontend is truly static and has no server-owned secret boundary.
- Create or update the `Microsoft Entra ID` app registration from Azure CLI or `az rest`, and keep redirect URIs plus audience in versioned notes.
- For local development, prefer a dev or test app registration with localhost callback URLs, test identities, and tenant policy settings that let the team complete sign-in safely without weakening production registration hygiene.
- If developers need the same sign-in behavior as production, replicate the relevant Conditional Access, consent, and token-lifetime policies in the dev or test environment instead of bypassing auth in application code.
- When a `web` registration needs a confidential client secret or certificate, keep it in Key Vault and resolve it through the same secretless config path used in production rather than copying it into `.env`.
- Keep authorization decisions in use cases or domain policies.
- Keep provider profile DTOs out of `domain` until a stable internal model is necessary.
- Document environment-specific callback URLs in README and app registration notes.

### 4. Add persistence and identity intentionally

- Keep repository ports in the companion skill's domain layer, and place Azure SQL or SQL Server adapters in `app/lib/server/infrastructure/repositories/`.
- Use local `DefaultAzureCredential` in development, and use `ManagedIdentityCredential` for deployed app-to-Azure and Azure SQL authentication when the driver path supports it.
- Keep migrations explicit and separate from app startup.
- Keep `db_datareader` and `db_datawriter` on runtime identities. Reserve elevated roles for migration or admin identities.

### 5. Prepare Azure deployment

- Add a container-friendly `Dockerfile`.
- Add `azure.yaml` and declarative infrastructure.
- Prefer Container Apps, Managed Identity, Azure App Configuration, Key Vault, Application Insights, and, when relational persistence is required, Azure SQL serverless as the default platform set.
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
- When the app requires user authentication, verify the documented local sign-in path with the intended dev or test users before release.
- Smoke-test the deployed revision and confirm callback URLs, health checks, and DB connectivity.

### 8. Operate and hand off cleanly

- Update README with architecture, Azure topology, required config keys and identities, callback URLs, and release flow.
- Record what is verified versus what still needs cloud-side confirmation.
- Avoid leaving partial infrastructure, stale releases, or unmanaged identities without noting the follow-up work.

## Placement Guide

- Need core React Router clean-architecture rules: use the sibling `../enforce-react-spa-architecture/` references.
- Need Azure IaC: `infra/`
- Need Azure deployment scripts: `scripts/azure/`
- Need GitHub release and deploy workflows: `.github/workflows/`
- Need health probes: `app/routes/health.ts`
- Need `Microsoft Entra ID` auth contract, callback, or local sign-in guidance when authentication is required: `references/entra-user-auth-and-runtime-contracts.md`
- Need reproducible Azure CLI or `az rest` app registration setup: `references/entra-app-registration-cli.md`
- Need secretless server config bootstrap, App Configuration, Key Vault, or local `DefaultAzureCredential` guidance: `references/azure-workload-identity-and-secretless-config.md`
- Need Azure SQL identity and permission guidance: `references/azure-sql-identity-and-permissions.md`
- Need server config bootstrap and parsing implementation placement: `app/lib/server/infrastructure/config/` or the narrowest equivalent under `app/lib/server/infrastructure/`
- Need Azure SQL or SDK adapters implementation placement: `app/lib/server/infrastructure/repositories/` and `app/lib/server/infrastructure/gateways/`
- Need runtime config contract documentation: `README.md`

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
- Azure identity overview index: [`references/azure-identity-and-sql.md`](references/azure-identity-and-sql.md)
- user auth, runtime contract, and local sign-in path: [`references/entra-user-auth-and-runtime-contracts.md`](references/entra-user-auth-and-runtime-contracts.md)
- Azure CLI and `az rest` app registration flow: [`references/entra-app-registration-cli.md`](references/entra-app-registration-cli.md)
- workload identity and secretless config: [`references/azure-workload-identity-and-secretless-config.md`](references/azure-workload-identity-and-secretless-config.md)
- Azure SQL identity and permissions: [`references/azure-sql-identity-and-permissions.md`](references/azure-sql-identity-and-permissions.md)
- GitHub repository operations: [`references/github-repository-operations.md`](references/github-repository-operations.md)
- GitHub release delivery: [`references/github-release-delivery.md`](references/github-release-delivery.md)
- template adoption guide: [`references/template-assets.md`](references/template-assets.md)
- operational checklist: [`references/operational-checklist.md`](references/operational-checklist.md)
