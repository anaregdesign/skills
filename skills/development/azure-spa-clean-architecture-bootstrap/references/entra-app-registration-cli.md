# Entra App Registration CLI

Use this reference when the app requires `Microsoft Entra ID` and the team needs a reproducible `az` or `az rest` setup path.

## Create a Microsoft Entra ID App Registration from Azure CLI When Authentication Is Required

Use Azure CLI for repeatable app registration setup instead of portal-only steps. Skip this section when the app does not need authentication.

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
- Keep the `appId`, object ID, and tenant ID in deployment notes, checked-in config docs, or Azure App Configuration records, not in ad hoc chat transcripts or `.env` files.
- Prefer separate registrations such as `myapp-web-dev` and `myapp-web-prod` when the app requires auth, rather than constantly mutating one registration between localhost and production concerns.

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

## Verification

- Verify `web` registrations use `web` redirect URIs and browser-only `spa` registrations use `spa` redirect URIs.
- Verify local and production callback URLs are both registered before testing login.
- Verify server-runtime secrets land in managed secret storage and are never committed.
