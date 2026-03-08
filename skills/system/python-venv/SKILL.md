---
name: python-venv
description: Always use this skill before any explicit or implicit Python execution in a workspace (for example python/python3 commands, shebang scripts, test/build tools that invoke Python, uv run, uvx, pip, poetry, tox, or nox). Provision and activate uv environments under workspace-dir/python/vX.Y.Z, switch Python versions, and manage dependencies with uv add, uv lock, and uv sync.
---

# Python Venv Environment Provider

## Hard Rules

- Always place projects under `<workspace-dir>/python/vX.Y.Z`.
- Resolve absolute `<workspace-dir>` from MCPHost app context (for example workspace metadata, current project root, or an environment variable such as `PYTHON_VENV_WORKSPACE_DIR`).
- Never depend on caller `cwd` to choose project location.
- MCPHost can run CLI directly. Do not require helper script files.
- Invoke this skill before any Python code execution in the workspace.
- This skill performs environment provisioning only. Do not execute user Python code in this skill.
- Do not generate business/domain artifacts (for example deck plans, chart specs, PPTX files).
- If the requested version does not exist yet, create it and activate it.
- For dependency changes, run `uv add`, then `uv lock`, then `uv sync` in the target version project.
- If version is not specified, default to `3.12.8`.
- Call `path` at most once at the end of provisioning. Do not poll it in a loop.

## Prerequisites

- Require `uv` in `PATH`. Check with `uv --version`.
- If `uv` is missing on macOS, run `brew install uv`.
- If `uv` is missing on Linux, run `curl -LsSf https://astral.sh/uv/install.sh | sh`.
- If `uv` is missing on Windows (PowerShell), run `winget install --id=astral-sh.uv -e`.
- If `winget` is unavailable, run `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`.
- For current options, see `https://docs.astral.sh/uv/getting-started/installation/`.

## Handoff Contract

- Scope of this skill: create/switch Python virtual environments and manage Python packages only.
- After provisioning, return only:
  - version used,
  - resolved environment directory from `path <version>`,
  - packages added (if any).
- Do not continue into domain workflow steps after this handoff.

## Action Semantics

Use these action labels as procedural units. Implement them with direct shell commands.

1. `ensure <version>`
   - Create `<workspace-dir>/python/vX.Y.Z`.
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
   - Print resolved `<workspace-dir>/python/vX.Y.Z` path.

## Environment Provisioning Protocol

When asked for a Python environment, perform the following in order:

1. Choose version:
   - User-specified version if provided.
   - Otherwise `3.12.8`.
2. Resolve `env_dir="<workspace-dir>/python/v<version>"`.
3. Run `ensure` then `activate`.
4. If dependency updates are requested, run `add`.
5. Return `path` once at the end.

## MCPHost CLI Contract

1. Resolve absolute `<workspace-dir>` first.
2. Execute one `bash -lc` command that includes:
   - workspace path input passed from MCPHost (for example `PYTHON_VENV_WORKSPACE_DIR="<workspace-dir>"`),
   - direct `uv` commands for `ensure` and (if needed) `activate` / `add` / `path`.
3. Run in this order:
   - `use`,
   - optional `add`,
   - `path` (once at end).

```bash
bash -lc '
PYTHON_VENV_WORKSPACE_DIR="<workspace-dir>"
version="3.12.8"
env_dir="$PYTHON_VENV_WORKSPACE_DIR/python/v$version"
mkdir -p "$env_dir"
cd "$env_dir"
test -f pyproject.toml || uv init --bare --python "$version" --name "python_v${version//./_}"
uv venv --python "$version" --allow-existing
source "$env_dir/.venv/bin/activate"
'
```

## Direct Command Notes

- `add` should skip non-Python dependencies such as `pptxgenjs` / `npm:pptxgenjs` and print install guidance instead of failing.
- `path` should print `<workspace-dir>/python/v<version>`.
- `deactivate` should be used only when explicitly switching environments.
