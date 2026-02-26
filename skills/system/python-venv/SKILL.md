---
name: python-venv
description: Provide Python environment provisioning with uv under this skill's assets directory. Create and activate versioned environments at assets/vX.Y.Z, switch Python versions, and manage dependencies with uv add, uv lock, uv sync.
---

# Python Venv Environment Provider

## Hard Rules

- Always place projects under `<skill-dir>/assets/vX.Y.Z`.
- Resolve `<skill-dir>` by finding the full path of `SKILL.md` first, then use its parent directory.
- Never depend on caller `cwd` to choose project location.
- Do not run only `source .../python-venv.<shell>`; always execute an action in the same command.
- This skill performs environment provisioning only. Do not execute user Python code in this skill.
- Do not generate business/domain artifacts (for example deck plans, chart specs, PPTX files).
- If the requested version does not exist yet, create it and activate it.
- For dependency changes, run `uv add`, then `uv lock`, then `uv sync` in the target version project.
- If version is not specified, default to `3.12.8`.
- Call `path` at most once at the end of provisioning. Do not poll it in a loop.

## Handoff Contract

- Scope of this skill: create/switch Python virtual environments and manage Python packages only.
- After provisioning, return only:
  - version used,
  - resolved environment directory from `python_venv path <version>`,
  - packages added (if any).
- Do not continue into domain workflow steps after this handoff.

## Minimal Work Units

The shell scripts expose one command with these units:

1. `ensure <version>`
   - Create `<skill-dir>/assets/vX.Y.Z`.
   - Initialize uv project if missing.
   - Create `.venv` with the requested Python version.
2. `activate <version>`
   - Activate existing venv.
   - If venv is missing, run `ensure` first.
3. `deactivate`
   - Deactivate current venv if active.
   - Use this only when you explicitly want to leave the active environment.
4. `use <version>`
   - Run `ensure`.
   - If another venv is active, `deactivate` first.
   - Activate requested version.
5. `add <version> <deps...>`
   - Run `ensure`.
   - Run `uv add <deps...>`, `uv lock`, `uv sync`.
   - If non-Python dependencies are included (for example `pptxgenjs`), skip them and show install guidance.
6. `path <version>`
   - Print resolved `<skill-dir>/assets/vX.Y.Z` path.

## Environment Provisioning Protocol

When asked for a Python environment, perform the following in order:

1. Choose version:
   - User-specified version if provided.
   - Otherwise `3.12.8`.
2. Run `python_venv use <version>` to create and activate the environment.
3. If dependency updates are requested, run `python_venv add <version> <deps...>`.
4. Return the environment path from `python_venv path <version>` (single call only).

## One-Liner Command Pattern

Run the action in the same command where the script is loaded.

```bash
bash -lc 'source <skill-dir>/scripts/python-venv.bash && python_venv use 3.12.8'
```

```zsh
zsh -lc 'source <skill-dir>/scripts/python-venv.zsh && python_venv add 3.12.8 requests'
```

```fish
fish -c 'source <skill-dir>/scripts/python-venv.fish; python_venv use 3.12.8'
```

```powershell
pwsh -NoProfile -Command ". <skill-dir>/scripts/python-venv.ps1; python_venv use 3.12.8"
```

## Shell-Specific Scripts

- Bash: `scripts/python-venv.bash`
- Zsh: `scripts/python-venv.zsh`
- Fish: `scripts/python-venv.fish`
- PowerShell: `scripts/python-venv.ps1`

Load the script for the current shell, then call `python_venv`.

## Usage Examples

### Bash

```bash
bash -lc 'source <skill-dir>/scripts/python-venv.bash && python_venv use 3.12.8'
bash -lc 'source <skill-dir>/scripts/python-venv.bash && python_venv add 3.12.8 pytest ruff'
bash -lc 'source <skill-dir>/scripts/python-venv.bash && python_venv path 3.12.8'
```

### Zsh

```zsh
zsh -lc 'source <skill-dir>/scripts/python-venv.zsh && python_venv use 3.11.11'
zsh -lc 'source <skill-dir>/scripts/python-venv.zsh && python_venv add 3.11.11 requests'
zsh -lc 'source <skill-dir>/scripts/python-venv.zsh && python_venv path 3.11.11'
```

### Fish

```fish
fish -c 'source <skill-dir>/scripts/python-venv.fish; python_venv use 3.10.14'
fish -c 'source <skill-dir>/scripts/python-venv.fish; python_venv add 3.10.14 numpy pandas'
fish -c 'source <skill-dir>/scripts/python-venv.fish; python_venv path 3.10.14'
```

### PowerShell

```powershell
pwsh -NoProfile -Command ". <skill-dir>/scripts/python-venv.ps1; python_venv use 3.13.1"
pwsh -NoProfile -Command ". <skill-dir>/scripts/python-venv.ps1; python_venv add 3.13.1 fastapi uvicorn"
pwsh -NoProfile -Command ". <skill-dir>/scripts/python-venv.ps1; python_venv path 3.13.1"
```

## Deactivate Guidance

- Use `python_venv deactivate` only when explicitly switching to another environment or clearing `VIRTUAL_ENV`.
- In non-interactive shells, `deactivate` fallback cleanup is handled by this skill.
