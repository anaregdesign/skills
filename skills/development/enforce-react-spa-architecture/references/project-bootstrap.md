# Project Bootstrap

Use this guide when starting a new project from scratch.

## Baseline Assumptions

Assume this stack unless the user explicitly says otherwise:

- TypeScript
- React Router framework mode
- SPA mode with `ssr: false`
- Fluent UI React v9 for the UI layer unless the repository already has an established design-system standard
- Prisma ORM v7
- PostgreSQL as the default SQL database
- Node.js 20.19+ or 22.x

If the database is not PostgreSQL, swap the Prisma driver adapter and datasource provider accordingly.
If a companion hosting skill explicitly requires a server runtime or a secretless platform-config bootstrap, let that companion override the `ssr: false` and local config-loading defaults in this file while keeping the rest of the layer rules.

## Preferred Bootstrap Path

For this skill's architecture, prefer React Router's official Vite-powered bootstrap over retrofitting a plain Vite template.

Reason:

- it matches `app/` and route-module conventions
- it keeps React Router configuration aligned with current framework mode
- it reduces manual setup drift before architecture work even starts

## Recommended Flow

### 1. Scaffold the app

```bash
npx create-react-router@latest my-app
cd my-app
```

Use the TypeScript option when prompted.

Keep the standard mobile viewport tag in the document head:

```html
<meta name="viewport" content="width=device-width, initial-scale=1" />
```

Add `viewport-fit=cover` only when the layout intentionally handles safe-area insets.

### 2. Switch the app to SPA mode by default

Create or update `react-router.config.ts`:

```ts
import type { Config } from "@react-router/dev/config";

export default {
  ssr: false,
} satisfies Config;
```

This keeps React Router in SPA mode while still using framework conventions.
If a companion hosting skill explicitly requires server runtime features such as OAuth callbacks, server-owned secrets, or platform-managed config bootstrap, do not force `ssr: false`.

### 3. Enable FlatRoute file routing

Install the file-route helper:

```bash
npm install @react-router/fs-routes
```

Create or update `app/routes.ts`:

```ts
import { flatRoutes } from "@react-router/fs-routes";
import type { RouteConfig } from "@react-router/dev/routes";

export default flatRoutes() satisfies RouteConfig;
```

This is the cleanest match for the route-file conventions used by this skill.

### 4. Install Prisma v7 and the database adapter

For the default PostgreSQL baseline:

```bash
npm install @prisma/client@7 @prisma/adapter-pg pg
npm install -D prisma@7 tsx @types/pg
```

Use the adapter package that matches the actual database if the project is not using PostgreSQL.

### 5. Install Fluent UI React v9

For the default UI baseline:

```bash
npm install @fluentui/react-components @fluentui/react-icons
```

Wrap the app root with `FluentProvider` and the appropriate theme, typically `webLightTheme`, before building feature screens:

```tsx
import {
  FluentProvider,
  webLightTheme,
} from "@fluentui/react-components";

export function AppShell({ children }: { children: React.ReactNode }) {
  return <FluentProvider theme={webLightTheme}>{children}</FluentProvider>;
}
```

If the repository already has a clearly established design system, follow that system instead of mixing component libraries casually.

### 6. Initialize Prisma

For a normal PostgreSQL database:

```bash
npx prisma init --datasource-provider postgresql --output ../app/lib/server/infrastructure/generated/prisma
```

If you intentionally use Prisma Postgres instead of your own PostgreSQL connection, use:

```bash
npx prisma init --db --output ../app/lib/server/infrastructure/generated/prisma
```

Keep the generated client under `app/lib/server/infrastructure/` so Prisma remains server-only by construction.

### 7. Configure Prisma for v7

Create or update `prisma.config.ts`:

```ts
import { defineConfig, env } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
    seed: "tsx prisma/seed.ts",
  },
  datasource: {
    url: env("DATABASE_URL"),
  },
});
```

Feed `DATABASE_URL` from the shell, the process environment, or a companion platform-specific bootstrap. Do not add `dotenv` only because this example uses `env("DATABASE_URL")`.

In `prisma/schema.prisma`, keep the generator output aligned with the server infrastructure layer:

```prisma
generator client {
  provider = "prisma-client"
  output   = "../app/lib/server/infrastructure/generated/prisma"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
```

### 8. Add a server-only Prisma bootstrap module

Create `app/lib/server/infrastructure/prisma.server.ts` and keep Prisma construction there.

Preferred responsibilities:

- read the database URL from process environment or a companion platform-specific config bootstrap
- create the driver adapter
- create or reuse the app-process `PrismaClient`
- export a narrow factory or singleton used only by server infrastructure

Do not import this module from `app/routes/`, `app/components/`, or `app/lib/client/`.

### 9. Add baseline database scripts

Add or keep these scripts in `package.json`:

```json
{
  "scripts": {
    "db:generate": "prisma generate",
    "db:migrate": "prisma migrate dev",
    "db:seed": "prisma db seed",
    "db:studio": "prisma studio"
  }
}
```

Prisma v7 no longer treats generation and seeding as automatic side effects. Run them explicitly.

### 10. Apply the first migration

```bash
npx prisma migrate dev --name init
npx prisma generate
```

Do not postpone the first migration until after multiple features exist. Establish the persistence boundary early.

### 11. Create the first architecture-aligned directories

Do not create every possible directory up front.

Create only the ones needed for the first feature or integration, usually:

```text
app/routes/
app/components/
app/lib/client/usecase/
app/lib/server/usecase/
app/lib/server/infrastructure/
app/lib/domain/
```

Add deeper directories such as `entities/`, `value-objects/`, `repositories/`, or `gateways/` when the first real owner appears.

## Plain Vite Fallback

Use plain Vite bootstrap only when one of these is true:

- the user explicitly requires `create-vite`
- the project intentionally uses React Router data mode or declarative mode instead of framework mode
- an existing starter must be retrofitted

Fallback start:

```bash
npm create vite@latest my-app -- --template react-ts
cd my-app
```

Then:

1. install the React Router packages required by the chosen mode
2. if you need this skill's framework conventions such as `app/routes/`, route modules, and FlatRoute naming, prefer re-bootstrapping with `create-react-router` instead of manually recreating the framework stack
3. install Prisma v7 and initialize it exactly as above

Do not treat plain `create-vite` as the default when the target architecture is React Router framework mode.

## Bootstrap Verification

Before starting feature work, confirm all of the following:

- `npm run dev` starts successfully
- SPA mode is enabled
- the standard mobile viewport meta tag is present
- FlatRoute routing is wired through `app/routes.ts`
- Fluent UI React v9 is installed and the app root is wrapped with `FluentProvider`
- Prisma client is generated under `app/lib/server/infrastructure/`
- no Prisma import exists outside server infrastructure
- the first migration runs successfully
- route modules and domain folders are present, even if still minimal
