# Azure Identity And SQL

Use this reference when the app needs Azure workload identity, Azure SQL, or social login backed by server-side persistence.

## Treat Microsoft Authentication Precisely

- Interpret requests for "Microsoft auth" as `Microsoft Entra ID` and `OpenID Connect` by default.
- Default to workforce sign-in with `AzureADMyOrg` unless the user explicitly needs multi-tenant workforce auth (`AzureADMultipleOrgs`) or personal Microsoft accounts (`AzureADandPersonalMicrosoftAccount`).
- Reach for another identity product only when requirements explicitly call for `External ID`, `Azure AD B2C`, or consumer-only sign-in.

## Choose the Correct App Registration Shape

- Use a `web` platform app registration when React Router framework runtime handles the callback, issues cookies, or needs server-owned secrets.
- Use a `spa` platform registration only for a truly static frontend that uses browser PKCE and has no client secret.
- Prefer one runtime contract per app registration. Do not casually mix `web` and `spa` redirect URI types in one registration unless the migration plan is explicit.
- Use browser `MSAL` only for true `spa` flows. When the app already has a server runtime, prefer server-side `OIDC` handling and cookie sessions.

## Separate the Identity Types

- Keep end-user social login separate from Azure workload identity.
- Use a GitHub Actions federated identity for deployment only.
- Use a Container App Managed Identity for runtime access to Azure resources.
- Use a separate migration or admin identity for schema changes and elevated SQL work.

## Create a Microsoft Entra ID App Registration from Azure CLI

Use Azure CLI for repeatable app registration setup instead of portal-only steps.

```bash
az login
az account set --subscription "<subscription-id-or-name>"

APP_NAME="myapp-web"
SIGN_IN_AUDIENCE="AzureADMyOrg"
LOCAL_ORIGIN="http://localhost:5173"
PROD_ORIGIN="https://app.contoso.com"
LOCAL_CALLBACK="$LOCAL_ORIGIN/auth/callback/microsoft"
PROD_CALLBACK="$PROD_ORIGIN/auth/callback/microsoft"

APP_ID="$(az ad app create \
  --display-name "$APP_NAME" \
  --sign-in-audience "$SIGN_IN_AUDIENCE" \
  --query appId -o tsv)"

OBJECT_ID="$(az ad app show --id "$APP_ID" --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

az ad app update \
  --id "$APP_ID" \
  --web-home-page-url "$PROD_ORIGIN" \
  --web-redirect-uris "$LOCAL_CALLBACK" "$PROD_CALLBACK"

az ad sp show --id "$APP_ID" >/dev/null 2>&1 || az ad sp create --id "$APP_ID" >/dev/null
```

- The current `az ad app create` flow also adds a default `user_impersonation` scope. If the app registration is only a sign-in client and is not exposing its own API, remove that exposed scope later or create the registration with `az rest` from the start.
- Keep the `appId`, object ID, and tenant ID in deployment notes or `.env.example` placeholders, not in ad hoc chat transcripts.

## Patch SPA Redirect URIs with `az rest` for True Browser-Only Flows

Use Microsoft Graph patching when the frontend is a real browser-only `spa` and the redirect URIs should live under the `spa` platform instead of `web`.

```bash
az rest \
  --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications/$OBJECT_ID" \
  --headers "Content-Type=application/json" \
  --body "{\"spa\":{\"redirectUris\":[\"$LOCAL_CALLBACK\",\"$PROD_CALLBACK\"]}}"
```

- If the app is moving from `web` to `spa`, clear stale `web.redirectUris` deliberately instead of leaving both contracts enabled by accident.
- Keep the callback path explicit. Do not rely on a root-path redirect unless the auth library is intentionally configured that way.

## Create a Client Secret Only for Server Runtime

Create a confidential client secret only when the app uses a `web` registration with a server-owned callback and session boundary.

```bash
CLIENT_SECRET="$(az ad app credential reset \
  --id "$APP_ID" \
  --append \
  --display-name "web-runtime" \
  --years 1 \
  --query password -o tsv)"
```

- Store the secret in Key Vault or another managed secret store immediately after creation.
- Do not create a client secret for a true browser-only `spa`.

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
- Keep `Microsoft Entra ID` app registration details aligned with the runtime contract so the callback code and redirect platform do not drift apart.
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
- Keep auth-facing config explicit: `MICROSOFT_ENTRA_CLIENT_ID`, `MICROSOFT_ENTRA_TENANT_ID`, `MICROSOFT_ENTRA_CLIENT_SECRET` for `web` only, and callback or origin URLs per environment.
- Keep Azure identity IDs, DB host names, and callback URLs documented in README or deployment notes.
- Keep GitHub Environment values separate from Azure runtime secrets.

## Verification

- Verify the selected `signInAudience` matches the expected tenant scope.
- Verify `web` registrations use `web` redirect URIs and browser-only `spa` registrations use `spa` redirect URIs.
- Verify local and production callback URLs are both registered before testing login.
- Verify server-runtime secrets land in managed secret storage and are never committed.
- Verify the deploy identity can update the Azure hosting resource and nothing broader than necessary.
- Verify the runtime identity can reach Azure SQL and only the intended database roles are granted.
- Verify local development still has a sane fallback path when Managed Identity is unavailable.
