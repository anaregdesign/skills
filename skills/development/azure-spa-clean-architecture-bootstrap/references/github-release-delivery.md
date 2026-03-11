# GitHub Release Delivery

Use this reference when the app needs GitHub-based CI/CD, container publishing, or release-driven deployment to Azure.

## Default GitHub Delivery Model

- Run quality gates on push and pull request.
- Build and publish the production container image on `release.published`.
- Deploy only after the image publish job succeeds.
- Promote immutable release-tag images such as `v1.2.3`, not mutable tags such as `latest`.

## Prefer This Workflow Shape

- One workflow may handle both image publish and deploy jobs if the deploy job depends on publish success.
- Use `needs: publish` so deploy cannot race ahead of image availability.
- Skip production deploys for prereleases unless the repository has an explicit prerelease environment.
- Run a smoke test against `/health` after deploy.

## Use OIDC Instead of Azure Client Secrets

- Create a GitHub Actions federated identity in Microsoft Entra.
- Scope the subject to the repository and environment.
- Use GitHub Environment protection for production.
- Store non-secret IDs such as tenant, subscription, and client IDs as GitHub Environment variables.

## Prefer These GitHub Variables

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_RESOURCE_GROUP`
- `AZURE_CONTAINER_APP_NAME`

## Add Package Registry Auth Only When Needed

- If the GHCR package is public, do not add unnecessary pull credentials.
- If the package is private, keep registry credentials scoped to the environment and document why GHCR cannot remain public.
- Prefer eliminating credential requirements over proliferating more secrets.

## Keep Release Metadata Clean

- Update README, screenshots, and configuration contract docs before the release when those artifacts changed.
- Use generated release notes as a baseline, then correct them when deploy behavior or operational caveats matter.
- Avoid mutating old releases to cover broken workflow definitions. Publish a new patch release instead.

## Validate the Workflow

- Run YAML validation locally.
- Run `actionlint` before pushing workflow edits.
- Check GitHub Actions context availability rules when expressions appear in `env`, `if`, or matrix definitions.
- Confirm the workflow is triggered by the intended event before cutting a release.

## Verify the Deployment

- Confirm the publish job pushed the expected tag.
- Confirm the deploy job updated the intended Azure resource.
- Confirm the smoke test passed.
- Capture the release URL, workflow run URL, and deployed app URL in the handoff.
