# skills

Skill Registry for [local-playground](https://github.com/anaregdesign/local-playground).

## Directory Structure

Skills are organized in the following hierarchy:

```
skills/
└── <tag>/
    └── <skill-name>/
        └── README.md
```

### Tags

Tags represent use-case categories that group related skills together.
Examples include `Developer`, `OfficeWorker`, etc.

### Adding a Skill

1. Choose (or create) an appropriate tag directory under `skills/`.
2. Create a new directory for your skill: `skills/<tag>/<skill-name>/`.
3. Add a `README.md` inside the skill directory describing the skill in English.

## Available Skills

| Tag | Skill | Description |
|-----|-------|-------------|
| Developer | [hello-world](skills/Developer/hello-world/) | A minimal example skill that prints "Hello, World!" |
| OfficeWorker | [summarize](skills/OfficeWorker/summarize/) | Summarizes a given text into a short paragraph |
