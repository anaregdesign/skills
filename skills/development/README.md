# development

Skills for software development workflows, architecture guardrails, and Azure delivery standards.

Each skill in this directory conforms to the [agentskills.io](https://agentskills.io/) specification.

## Overview

This directory currently contains:

- a companion pair for React Router + Prisma SPA architecture and Azure delivery
- one independent GitHub workflow skill

The companion pair is:

- `enforce-react-spa-architecture`: the base architecture skill
- `azure-spa-clean-architecture-bootstrap`: the Azure extension skill

The independent skill is:

- `gh-spec-driven-development`: the GitHub workflow and spec-first delivery skill

## Skill Roles

### `enforce-react-spa-architecture`

Role:
- Owns code structure, dependency direction, module placement, UI guardrails, commit hygiene, and pre-push verification for Vite-powered React Router + Prisma v7 apps.

Use this skill for:
- project bootstrap with React Router + Prisma v7
- feature implementation and refactoring
- keeping `app/routes/` thin and `app/components/` presentational
- `app/lib/client/usecase/` ownership of client orchestration
- Fluent UI React v9 guidance for new UI work
- responsive UI, charts, Playwright verification, and Conventional Commits guidance

This skill does not own:
- cloud provider choice
- app registration or identity provisioning
- secret-store topology
- IaC or release infrastructure

### `azure-spa-clean-architecture-bootstrap`

Role:
- Extends `enforce-react-spa-architecture` with Azure hosting, identity, secretless config, IaC, Azure SQL, and GitHub delivery guidance.

Use this skill for:
- Azure Container Apps, Azure SQL, and Azure topology choices
- `Microsoft Entra ID` only when end-user authentication is actually required
- `Managed Identity`, local `DefaultAzureCredential`, Azure App Configuration, and Key Vault guidance
- Azure CLI or `az rest` app registration flows
- GitHub Releases, GHCR, GitHub Actions OIDC, and release workflow setup

This skill does not replace:
- the base architecture rules from `enforce-react-spa-architecture`

### `gh-spec-driven-development`

Role:
- Documents spec-first GitHub development flow for feature work.

Use this skill for:
- writing complete user-visible requirements under `/doc/spec/`
- creating or updating GitHub Issues for development work
- creating semantic branches such as `feat/`, `fix/`, `docs/`, or `refactor/`
- opening draft PRs early
- breaking work into the shortest meaningful Issue checkbox steps
- checking off work as it completes
- merging PRs, closing Issues, and deleting branches cleanly

This skill is independent:
- use it on its own for GitHub-backed product delivery workflow
- do not treat it as an extension of the SPA or Azure skills

## Dependency Direction

The SPA companion pair has a one-way dependency direction:

```text
azure-spa-clean-architecture-bootstrap
  -> enforce-react-spa-architecture
```

Interpretation:
- Install `enforce-react-spa-architecture` first.
- Install `azure-spa-clean-architecture-bootstrap` only as an extension on top of it.
- Keep base code-level architecture rules in the base skill.
- Keep Azure, identity, infrastructure, and delivery rules in the Azure skill.
- Repeat only the most important cross-cutting reminders in both skills when they protect boundary integrity.

## Which To Use

- Use only `enforce-react-spa-architecture` when you need code architecture and implementation guardrails for a React Router + Prisma v7 app without Azure-specific delivery concerns.
- Use both skills together when the same app must also ship on Azure or needs Azure-specific identity, SQL, config, IaC, or release workflow guidance.
- Use `gh-spec-driven-development` when you want spec-first GitHub execution with `/doc/spec/`, Issue checklists, semantic branches, early PRs, and merge cleanup.
- Do not install `azure-spa-clean-architecture-bootstrap` by itself.

## Install Together

`azure-spa-clean-architecture-bootstrap` extends `enforce-react-spa-architecture`, so install both skills together.
Install `gh-spec-driven-development` separately when the repository also needs the spec-first GitHub workflow.

### Codex

```text
Use `$skill-installer` to install these two skills together into my personal Codex skills directory (`$CODEX_HOME/skills` or `~/.codex/skills`) from this repository:

- https://github.com/anaregdesign/skills/tree/main/skills/development/enforce-react-spa-architecture
- https://github.com/anaregdesign/skills/tree/main/skills/development/azure-spa-clean-architecture-bootstrap

Requirements:
- Install `enforce-react-spa-architecture` first, then `azure-spa-clean-architecture-bootstrap`.
- Treat `enforce-react-spa-architecture` as the base architecture skill and `azure-spa-clean-architecture-bootstrap` as its Azure extension.
- Preserve the original folder names.
- Install from the GitHub repo paths rather than manually retyping the skill contents.
- If either destination skill already exists, stop and report that instead of overwriting it implicitly.
- When finished, list the installed paths, confirm both skills are available, and remind me to restart Codex to pick up new skills.
```

### Claude Code

```text
Copy these two skills into the current project's `.claude/skills/` directory:

- https://github.com/anaregdesign/skills/tree/main/skills/development/enforce-react-spa-architecture
- https://github.com/anaregdesign/skills/tree/main/skills/development/azure-spa-clean-architecture-bootstrap

Requirements:
- Create `.claude/skills/enforce-react-spa-architecture/`
- Create `.claude/skills/azure-spa-clean-architecture-bootstrap/`
- Preserve every file and subdirectory exactly.
- Treat `enforce-react-spa-architecture` as the required base skill and `azure-spa-clean-architecture-bootstrap` as the Azure extension.
- Install both together, in that order.
- If destination folders already exist, replace or sync them to the repository version.
- When finished, show the resulting `.claude/skills/` tree.
```

### GitHub Copilot

```text
Copy these two agent skills into this repository under `.github/skills/`:

- https://github.com/anaregdesign/skills/tree/main/skills/development/enforce-react-spa-architecture
- https://github.com/anaregdesign/skills/tree/main/skills/development/azure-spa-clean-architecture-bootstrap

Install both together because `azure-spa-clean-architecture-bootstrap` extends `enforce-react-spa-architecture`.

Requirements:
- Create `.github/skills/enforce-react-spa-architecture/`
- Create `.github/skills/azure-spa-clean-architecture-bootstrap/`
- Copy the complete contents of each source directory exactly, including `SKILL.md`, `agents/openai.yaml`, `references/`, `assets/`, and `scripts/` if present.
- Preserve relative links between the two skills.
- Treat `enforce-react-spa-architecture` as the base architecture skill and `azure-spa-clean-architecture-bootstrap` as the Azure extension.
- If destination folders already exist, replace or sync them to the repository version.
- When finished, list the installed files under `.github/skills/`.
```
