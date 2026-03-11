# Azure Identity And SQL

Use this overview when the app needs Azure workload identity, Azure SQL, or `Microsoft Entra ID` backed by server-side persistence. Open the narrower reference that matches the specific task instead of reading one large mixed file.

## Reference Map

- End-user auth, runtime contract choice, and local sign-in path: [`entra-user-auth-and-runtime-contracts.md`](entra-user-auth-and-runtime-contracts.md)
- Reproducible `az` and `az rest` app registration work: [`entra-app-registration-cli.md`](entra-app-registration-cli.md)
- Secretless config, workload identity, and local `DefaultAzureCredential`: [`azure-workload-identity-and-secretless-config.md`](azure-workload-identity-and-secretless-config.md)
- Azure SQL role model, `Managed Identity`, and runtime versus migration permissions: [`azure-sql-identity-and-permissions.md`](azure-sql-identity-and-permissions.md)

## Usage

- Open the auth contract reference first when the app has a user sign-in requirement.
- Open the CLI reference when redirect URIs, audience, or confidential-client setup must be reproducible.
- Open the workload identity reference when the app needs App Configuration, Key Vault, or local Azure bootstrap without `.env`.
- Open the Azure SQL reference when the app needs DB identity design, role assignment, or permission separation.
