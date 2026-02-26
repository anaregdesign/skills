# skills

Skill Registry for [local-playground](https://github.com/anaregdesign/local-playground).
This repository contains [agentskills.io](https://agentskills.io/)-compliant skills.

## Directory Structure

Skills are organized in the following hierarchy:

```
skills/
└── <tag>/
    └── <skill-name>/
        └── (agentskills.io-compliant skill files)
```

### Tags

Tags represent use-case categories that group related skills together.
Examples: `<tag-a>`, `<tag-b>`, etc.

### Skill Specification

Each `<skill-name>` directory must contain a skill that conforms to the
[agentskills.io](https://agentskills.io/) specification.

### Adding a Skill

1. Choose (or create) an appropriate tag directory under `skills/`.
2. Create a new directory for your skill: `skills/<tag>/<skill-name>/`.
3. Place the [agentskills.io](https://agentskills.io/)-compliant skill files inside the skill directory.

## Available Tags

| Tag |
|-----|
| example |
| finance |
| japanese-business |
| presentation |
| system |
