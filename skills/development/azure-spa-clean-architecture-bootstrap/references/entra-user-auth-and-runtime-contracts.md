# Entra User Auth And Runtime Contracts

Use this reference when the app has an end-user authentication requirement and the team needs to choose the correct runtime and sign-in contract.

## Treat Microsoft Authentication Precisely

- Interpret requests for "Microsoft auth" as `Microsoft Entra ID` and `OpenID Connect` only when the app actually needs authentication.
- Default to workforce sign-in with `AzureADMyOrg` unless the user explicitly needs multi-tenant workforce auth (`AzureADMultipleOrgs`) or personal Microsoft accounts (`AzureADandPersonalMicrosoftAccount`).
- Reach for another identity product only when requirements explicitly call for `External ID`, `Azure AD B2C`, or consumer-only sign-in.

## Choose the Correct App Registration Shape

- Use a `web` platform app registration when React Router framework runtime handles the callback, issues cookies, or needs server-owned secrets.
- Use a `spa` platform registration only for a truly static frontend that uses browser PKCE and has no client secret.
- Prefer one runtime contract per app registration. Do not casually mix `web` and `spa` redirect URI types in one registration unless the migration plan is explicit.
- Use browser `MSAL` only for true `spa` flows. When the app already has a server runtime, prefer server-side `OIDC` handling and cookie sessions.

## Prefer a Real Local Sign-In Path for Apps That Require User Authentication

- Do not make a hidden development auth bypass the default local path for an app that actually requires user sign-in.
- Prefer a separate dev or test app registration from the production registration so localhost redirects, consent experiments, and test-user assignments do not pollute the production registration.
- When production-tenant policies or risk make safe local testing hard, prefer a separate test tenant instead of weakening the production tenant setup.
- Register localhost redirect URIs only for the dev or test registration unless there is a deliberate, documented reason to keep them elsewhere.
- Use test users, assigned test groups, or invited guest users for developer sign-in instead of broad tenant-wide assignment.
- If the test app lives in the production tenant, require explicit user or group assignment on the Enterprise Application so only intended testers can use it.
- Keep the normal local sign-in path as close to production behavior as practical by reproducing the relevant consent, Conditional Access, and token-lifetime expectations in the dev or test environment.

## Handle Social Login at the Server Edge

- Only apply this section when the app actually has a user-authentication requirement.
- Keep OAuth callback handling in routes or server entry points.
- Keep provider tokens, session cookies, and refresh behavior outside `domain`.
- Keep `Microsoft Entra ID` app registration details aligned with the runtime contract so the callback code and redirect platform do not drift apart.
- Keep the local callback and sign-in path explicit for developers: which tenant, which app registration, which localhost callback URL, and which test identities should be used.
- Keep confidential client material out of `.env`; resolve it from Key Vault in the server composition layer when needed.
- Map provider profile DTOs into stable internal user shapes only at the application boundary.
- Document callback URLs for local, staging, and production environments.

## Verification

- Verify the selected `signInAudience` matches the expected tenant scope.
- Verify the chosen runtime contract is deliberate: `web` for server-owned callback and session handling, `spa` for true browser-only PKCE flows.
- Verify developers can complete local sign-in with the intended test users, guest users, or assigned groups and without a hidden auth bypass path.
- Verify the dev or test registration is isolated from production registration when that isolation is required by risk, policy, or tenant setup.
