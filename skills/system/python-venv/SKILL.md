---
name: python-venv
description: Provide and enforce Python execution environments with uv under this skill's assets directory. Before any Python execution, always create/use assets/vX.Y.Z, activate it, then run Python. Also supports version switching and dependency updates with uv add, uv lock, uv sync.
---

# Python Venv Environment Provider

## Hard Rules

- Always place projects under `<skill-dir>/assets/vX.Y.Z`.
- Resolve `<skill-dir>` by finding the full path of `SKILL.md` first, then use its parent directory.
- Never depend on caller `cwd` to choose project location.
- Do not run only `source .../python-venv.<shell>`; always execute an action in the same command.
- Before any Python execution, always run environment creation/selection first.
- Never run `python`/`python3` directly before `python_venv use` or `python_venv run`.
- If the requested version does not exist yet, create it and activate it.
- For dependency changes, run `uv add`, then `uv lock`, then `uv sync` in the target version project.
- If version is not specified, default to `3.12.8`.

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
5. `run <version> <python-args...>`
   - Run `ensure`.
   - If another venv is active, `deactivate` first.
   - Activate requested version.
   - Run `python <python-args...>`.
6. `add <version> <deps...>`
   - Run `ensure`.
   - Run `uv add <deps...>`, `uv lock`, `uv sync`.
7. `path <version>`
   - Print resolved `<skill-dir>/assets/vX.Y.Z` path.

## Mandatory Python Execution Protocol

When asked to execute Python, perform the following in order:

1. Choose version:
   - User-specified version if provided.
   - Otherwise `3.12.8`.
2. Run `python_venv run <version> <python-args...>`.
3. Only after step 2, report Python output.

## One-Liner Command Pattern

Run the action in the same command where the script is loaded.

```bash
bash -lc 'source <skill-dir>/scripts/python-venv.bash && python_venv run 3.12.8 -c "import sys; print(sys.version)"'
```

```zsh
zsh -lc 'source <skill-dir>/scripts/python-venv.zsh && python_venv add 3.12.8 requests'
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
source <skill-dir>/scripts/python-venv.bash
python_venv run 3.12.8 -c "import sys; print(sys.version)"
python_venv add 3.12.8 pytest ruff
python_venv use 3.13.1
python_venv deactivate
```

### Zsh

```zsh
source <skill-dir>/scripts/python-venv.zsh
python_venv run 3.11.11 -c "import sys; print(sys.version)"
python_venv add 3.11.11 requests
python_venv use 3.12.8
python_venv deactivate
```

### Fish

```fish
source <skill-dir>/scripts/python-venv.fish
python_venv run 3.10.14 -c "import sys; print(sys.version)"
python_venv add 3.10.14 numpy pandas
python_venv use 3.11.11
python_venv deactivate
```

### PowerShell

```powershell
. <skill-dir>/scripts/python-venv.ps1
python_venv run 3.13.1 -c "import sys; print(sys.version)"
python_venv add 3.13.1 fastapi uvicorn
python_venv use 3.13.2
python_venv deactivate
```
