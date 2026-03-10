ARG NODE_VERSION=22.14.0

FROM node:${NODE_VERSION}-bookworm-slim AS base
WORKDIR /app
ENV CI=true

FROM base AS deps
COPY package.json package-lock.json* ./
RUN npm ci

FROM deps AS build
COPY . .
ARG PRISMA_DATABASE_URL="sqlserver://placeholder.invalid:1433;database=placeholder;encrypt=true;trustServerCertificate=false;authentication=ActiveDirectoryDefault"
ENV PRISMA_DATABASE_URL="${PRISMA_DATABASE_URL}"
ENV NODE_ENV=production
RUN npm run build
RUN npm prune --omit=dev

FROM node:${NODE_VERSION}-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
RUN addgroup --system nodejs && adduser --system --ingroup nodejs appuser
COPY --from=build /app /app
USER appuser
EXPOSE 3000
CMD ["npm", "run", "start"]
