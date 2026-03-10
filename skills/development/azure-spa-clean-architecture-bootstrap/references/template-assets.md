# Template Assets

Use this reference when copying files from `assets/templates/` into a target repository.

## Clean Architecture First

Templates are starting points, not architectural authority. Customize copied assets so they preserve the target repo's Clean Architecture boundaries instead of blindly inheriting convenience structure from scaffolding.

## Goals

- Start from working generic files instead of rewriting common Azure and GitHub scaffolding.
- Keep the shared templates free of app-specific vocabulary.
- Apply naming and environment-specific values only in the destination repository.

## Placeholder Rules

- Use uppercase placeholder tokens wrapped in double underscores.
- Prefer infrastructure-neutral names such as `__APP_NAME__`, `__SERVICE_NAME__`, `__PUBLIC_APP_URL__`, and `__SESSION_SECRET__`.
- Do not hardcode project names, domain nouns, resource-group names, or callback URLs into the shared templates.
- Keep GitHub variable names generic and reusable across repositories.

## Template Inventory

- `assets/templates/azure.yaml`
- `assets/templates/Dockerfile`
- `assets/templates/.env.example`
- `assets/templates/app/routes/health.ts`
- `assets/templates/.github/workflows/release-container-image.yml`
- `assets/templates/scripts/azure/postprovision.sh`
- `assets/templates/infra/main.bicep`

## Adoption Flow

1. Copy only the files needed for the target repository.
2. Replace placeholder tokens in the copied files, not in the shared asset files.
3. Align the copied files with the target repo naming, package manager, and deploy topology.
4. Validate each copied file in the target repo before pushing.

## Validation Expectations

- Validate YAML files with a YAML parser.
- Validate GitHub workflow files with `actionlint`.
- Validate Bicep files with `az bicep build`.
- Validate the copied container image build locally or in CI.
