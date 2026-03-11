# development

Skills for software development workflows, architecture guidance, and implementation standards.

Each skill in this directory conforms to the [agentskills.io](https://agentskills.io/) specification.

## Available Skills

- `azure-spa-clean-architecture-bootstrap`: Extends the React Router SPA clean architecture guidance with Azure hosting, identity, SQL, and GitHub delivery workflows while keeping Clean Architecture as the highest-priority rule.
- `enforce-react-spa-architecture`: Enforces clean architecture as the highest-priority rule for Vite-powered React Router + Prisma v7 SPA projects.

## Install Together

`azure-spa-clean-architecture-bootstrap` extends `enforce-react-spa-architecture`, so install both skills together.

### Codex

```text
Install these two skills together into my personal Codex skills directory (`$CODEX_HOME/skills` or `~/.codex/skills`) from this repository:

- https://github.com/anaregdesign/skills/tree/main/skills/development/enforce-react-spa-architecture
- https://github.com/anaregdesign/skills/tree/main/skills/development/azure-spa-clean-architecture-bootstrap

Requirements:
- Keep the original folder names.
- Copy the complete contents of each skill directory, including `SKILL.md`, `agents/`, `references/`, `assets/`, and `scripts/` if present.
- Install `enforce-react-spa-architecture` first, then `azure-spa-clean-architecture-bootstrap`.
- If a destination folder already exists, sync it to match the repository version.
- When finished, list the installed paths and confirm both skills are available.
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
- Treat `enforce-react-spa-architecture` as a required companion skill and install it together with the Azure skill.
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
- If destination folders already exist, replace or sync them to the repository version.
- When finished, list the installed files under `.github/skills/`.
```
