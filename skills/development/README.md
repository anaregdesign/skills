# development

Skills for software development workflows, architecture guardrails, and Azure delivery standards.

Each skill in this directory conforms to the [agentskills.io](https://agentskills.io/) specification.

## Bootstrap

Bootstrap these skills first when the repository needs the full React Router + Prisma + Azure development stack plus spec-first planning.

### GitHub Copilot

```text
Bootstrap these three agent skills into this repository under `.github/skills/`:

- https://github.com/anaregdesign/skills/tree/main/skills/development/enforce-react-spa-architecture
- https://github.com/anaregdesign/skills/tree/main/skills/development/azure-spa-clean-architecture-bootstrap
- https://github.com/anaregdesign/skills/tree/main/skills/development/spec-driven-workflow

Requirements:
- Create `.github/skills/enforce-react-spa-architecture/`
- Create `.github/skills/azure-spa-clean-architecture-bootstrap/`
- Create `.github/skills/spec-driven-workflow/`
- Copy the complete contents of each source directory exactly, including `SKILL.md`, `agents/openai.yaml`, `references/`, `assets/`, and `scripts/` if present.
- Install `enforce-react-spa-architecture` first, then `azure-spa-clean-architecture-bootstrap`, then `spec-driven-workflow`.
- Treat `enforce-react-spa-architecture` as the base app-code architecture skill.
- Treat `azure-spa-clean-architecture-bootstrap` as the Azure extension that depends on `enforce-react-spa-architecture`.
- Treat `spec-driven-workflow` as an independent spec and planning skill.
- Preserve relative links between the two SPA skills.
- If destination folders already exist, replace or sync them to the repository version.
- Create or update `.github/copilot-instructions.md`.
- In `.github/copilot-instructions.md`, instruct Copilot to call:
  - `spec-driven-workflow` when the task needs `/doc/spec/`, `/doc/plan.md`, ordered Section/Subsection planning, or deliberate commit-unit planning
  - `enforce-react-spa-architecture` when the task changes React Router + Prisma app-code architecture, UI boundaries, or verification
  - `azure-spa-clean-architecture-bootstrap` when the task changes Azure hosting, identity, secretless config, IaC, or release automation
- In `.github/copilot-instructions.md`, instruct Copilot to combine the skills when a task spans multiple concerns, using `enforce-react-spa-architecture` as the base and `azure-spa-clean-architecture-bootstrap` only for Azure-specific deltas.
- When finished, list the installed files under `.github/skills/` and show the final `.github/copilot-instructions.md`.
```

### Codex

```text
Use `$skill-installer` to install these three skills into my personal Codex skills directory (`$CODEX_HOME/skills` or `~/.codex/skills`) from this repository:

- https://github.com/anaregdesign/skills/tree/main/skills/development/enforce-react-spa-architecture
- https://github.com/anaregdesign/skills/tree/main/skills/development/azure-spa-clean-architecture-bootstrap
- https://github.com/anaregdesign/skills/tree/main/skills/development/spec-driven-workflow

Requirements:
- Install `enforce-react-spa-architecture` first, then `azure-spa-clean-architecture-bootstrap`, then `spec-driven-workflow`.
- Treat `enforce-react-spa-architecture` as the base architecture skill and `azure-spa-clean-architecture-bootstrap` as its Azure extension.
- Treat `spec-driven-workflow` as an independent spec and planning skill.
- Use the full 3-skill set after install:
  - `spec-driven-workflow` for `/doc/spec/`, `/doc/plan.md`, ordered Section/Subsection planning, and deliberate commit-unit planning
  - `enforce-react-spa-architecture` for React Router + Prisma app-code architecture, UI boundaries, and verification
  - `azure-spa-clean-architecture-bootstrap` only for Azure-specific hosting, identity, secretless config, IaC, and release automation deltas
- When a task spans multiple concerns, combine the skills deliberately:
  - start with `spec-driven-workflow` for spec and plan
  - use `enforce-react-spa-architecture` as the base coding skill
  - add `azure-spa-clean-architecture-bootstrap` only when Azure-specific decisions are involved
- Preserve the original folder names.
- Install from the GitHub repo paths rather than manually retyping the skill contents.
- If any destination skill already exists, stop and report that instead of overwriting it implicitly.
- When finished, list the installed paths, confirm all three skills are available, summarize the above usage mapping, and remind me to restart Codex to pick up new skills.
```

### Claude Code

```text
Copy these three skills into the current project's `.claude/skills/` directory:

- https://github.com/anaregdesign/skills/tree/main/skills/development/enforce-react-spa-architecture
- https://github.com/anaregdesign/skills/tree/main/skills/development/azure-spa-clean-architecture-bootstrap
- https://github.com/anaregdesign/skills/tree/main/skills/development/spec-driven-workflow

Requirements:
- Create `.claude/skills/enforce-react-spa-architecture/`
- Create `.claude/skills/azure-spa-clean-architecture-bootstrap/`
- Create `.claude/skills/spec-driven-workflow/`
- Preserve every file and subdirectory exactly.
- Install `enforce-react-spa-architecture` first, then `azure-spa-clean-architecture-bootstrap`, then `spec-driven-workflow`.
- Treat `enforce-react-spa-architecture` as the required base skill and `azure-spa-clean-architecture-bootstrap` as the Azure extension.
- Treat `spec-driven-workflow` as an independent spec and planning skill.
- Create or update `CLAUDE.md` at the repository root.
- In `CLAUDE.md`, instruct Claude Code to use:
  - `spec-driven-workflow` when the task needs `/doc/spec/`, `/doc/plan.md`, ordered Section/Subsection planning, or deliberate commit-unit planning
  - `enforce-react-spa-architecture` when the task changes React Router + Prisma app-code architecture, UI boundaries, or verification
  - `azure-spa-clean-architecture-bootstrap` when the task changes Azure hosting, identity, secretless config, IaC, or release automation
- In `CLAUDE.md`, instruct Claude Code to combine the skills when a task spans multiple concerns, using `enforce-react-spa-architecture` as the base and `azure-spa-clean-architecture-bootstrap` only for Azure-specific deltas.
- If destination folders already exist, replace or sync them to the repository version.
- When finished, show the resulting `.claude/skills/` tree and the final `CLAUDE.md`.
```

## Overview

This directory currently contains:

- a companion pair for React Router + Prisma SPA architecture and Azure delivery
- one independent spec and planning workflow skill

The companion pair is:

- `enforce-react-spa-architecture`: the base architecture skill
- `azure-spa-clean-architecture-bootstrap`: the Azure extension skill

The independent skill is:

- `spec-driven-workflow`: the spec and plan workflow skill

## Skill Roles

### `enforce-react-spa-architecture`

Role:
- Owns code structure, dependency direction, module placement, UI guardrails, and pre-push verification for Vite-powered React Router + Prisma v7 apps.

Use this skill for:
- project bootstrap with React Router + Prisma v7
- feature implementation and refactoring
- keeping `app/routes/` thin and `app/components/` presentational
- `app/lib/client/usecase/` ownership of client orchestration
- Fluent UI React v9 guidance for new UI work
- responsive UI, charts, and Playwright verification

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

### `spec-driven-workflow`

Role:
- Documents spec-first planning flow and shared commit-log workflow for feature work.

Use this skill for:
- writing complete user-visible requirements under `/doc/spec/`
- creating and maintaining a temporary execution tracker in `/doc/plan.md`
- structuring that plan with ordered `Section`, `Subsection`, and optional `Sub-subsection` blocks only as needed
- breaking work into the shortest meaningful plan checkbox steps
- keeping commit history in deliberate work units and using Conventional Commits when the repository uses them
- checking off work as it completes and deleting `/doc/plan.md` when all tracked work is done
- keeping the temporary plan aligned with the durable spec

This skill is independent:
- use it on its own for spec-first planning workflow
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
- Use `spec-driven-workflow` when you want spec-first execution with `/doc/spec/` and a temporary `/doc/plan.md` that is deleted after the tracked work finishes.
- Do not install `azure-spa-clean-architecture-bootstrap` by itself.
