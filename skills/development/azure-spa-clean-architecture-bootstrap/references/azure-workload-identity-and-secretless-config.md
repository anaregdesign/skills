# Azure Workload Identity And Secretless Config

Use this reference when the app needs Azure workload identity, Azure App Configuration, Key Vault, or local `DefaultAzureCredential` bootstrap.

## Separate the Identity Types

- Keep end-user social login separate from Azure workload identity.
- Use a GitHub Actions federated identity for deployment only.
- Use a Container App Managed Identity for deployed runtime access to Azure resources and Azure SQL.
- Use a separate migration or admin identity for schema changes and elevated SQL work.

## Prefer Secretless Config Over `.env`

- Do not add `.env` or `.env.example` for Azure-hosted apps.
- Keep non-secret runtime settings in Azure App Configuration.
- Keep secrets such as confidential client secrets, API keys, and connection secrets in Key Vault.
- Bootstrap Azure App Configuration with Microsoft Entra ID rather than connection strings whenever possible.
- The Azure App Configuration endpoint is not a secret and can live in checked-in code, checked-in config files, or platform app settings when needed for bootstrap.

## Use Local `DefaultAzureCredential` During Development

- Run `az login` or `azd auth login` locally and use `DefaultAzureCredential` for the local development path.
- Grant the developer identity only the minimum local roles it needs, such as App Configuration Data Reader and Key Vault Secrets User where appropriate.
- Use the same Azure App Configuration and Key Vault path in local development that production will use, instead of creating a separate `.env`-driven config path.
- If a `web` app needs a confidential client secret locally, fetch it from Key Vault through `DefaultAzureCredential` rather than copying it into a local file.
- Keep local development documentation explicit about what the developer must sign in to and which Azure resources are read at startup.
- Inference from Microsoft guidance: keep `DefaultAzureCredential` for local development convenience, but do not describe that local path as Managed Identity. Use Managed Identity only in deployed Azure environments.

## Use `DefaultAzureCredential` Carefully

- Use `DefaultAzureCredential` for local development paths when the SDK or driver actually supports token-based auth.
- Do not assume Prisma CLI, migration tooling, or every SQL driver can use the same auth path automatically.
- If runtime auth works with Managed Identity but migration tooling needs a different connection path, document the split explicitly instead of hiding it.
- Use `ManagedIdentityCredential` for deployed app-to-Azure and Azure SQL authentication so production auth is predictable and easier to debug.

## Environment and Config Guidance

- Keep app-facing config parsing centralized.
- Keep Azure App Configuration as the source of truth for non-secret app settings and labels.
- Keep Key Vault as the source of truth for secrets, including `MICROSOFT_ENTRA_CLIENT_SECRET` for `web` apps when that secret is still required.
- Keep auth-facing config explicit, but not file-backed: `MICROSOFT_ENTRA_CLIENT_ID`, `MICROSOFT_ENTRA_TENANT_ID`, callback URLs, and other non-secret values can live in checked-in config or Azure App Configuration; secrets stay in Key Vault.
- Keep the local development auth path explicit in checked-in docs: which tenant, which app registration, which localhost callback URL, and which test users or groups are expected for developer sign-in.
- Keep Azure identity IDs, App Configuration endpoints, DB host names, and callback URLs documented in README or deployment notes.
- Keep GitHub Environment values separate from Azure runtime secrets.

## Verification

- Verify local development succeeds after `az login` or `azd auth login` with no `.env` file present.
- Verify the deploy identity can update the Azure hosting resource and nothing broader than necessary.
- Verify local development still works through `DefaultAzureCredential` without claiming that the developer workstation has Managed Identity.
