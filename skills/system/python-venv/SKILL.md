---
name: python-venv
description: Provide requested Python execution environments with uv under this skill's assets directory. Create and activate versioned projects at assets/vX.Y.Z, switch Python versions, and add dependencies with uv add, uv lock, uv sync.
---

# Python Venv Environment Provider

Use this skill when the user asks for a Python runtime environment, requests a different Python version, or asks to add dependencies to that environment.

## Hard Rules

- Always place projects under `<skill-dir>/assets/vX.Y.Z`.
- Never depend on caller `cwd` to choose project location.
- If the requested version does not exist yet, create it and activate it.
- For dependency changes, run `uv add`, then `uv lock`, then `uv sync` in the target version project.

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
6. `path <version>`
   - Print resolved `<skill-dir>/assets/vX.Y.Z` path.

## Shell-Specific Scripts

- Bash: `scripts/python-venv.bash`
- Zsh: `scripts/python-venv.zsh`
- Fish: `scripts/python-venv.fish`
- PowerShell: `scripts/python-venv.ps1`

Load the script for the current shell, then call `python_venv`.

## Usage Examples

### Bash

```bash
source <skill-dir>/scripts/python-venv.bash
python_venv use 3.12.8
python_venv add 3.12.8 pytest ruff
python_venv use 3.13.1
python_venv deactivate
```

### Zsh

```zsh
source <skill-dir>/scripts/python-venv.zsh
python_venv use 3.11.11
python_venv add 3.11.11 requests
python_venv use 3.12.8
python_venv deactivate
```

### Fish

```fish
source <skill-dir>/scripts/python-venv.fish
python_venv use 3.10.14
python_venv add 3.10.14 numpy pandas
python_venv use 3.11.11
python_venv deactivate
```

### PowerShell

```powershell
. <skill-dir>/scripts/python-venv.ps1
python_venv use 3.13.1
python_venv add 3.13.1 fastapi uvicorn
python_venv use 3.13.2
python_venv deactivate
```

## Behavior for Version Switch Requests

If the user asks for another Python version, run `python_venv use <new-version>`.
This creates `<skill-dir>/assets/v<new-version>` when needed and activates that version.
If another venv is active, it is deactivated before switching.
