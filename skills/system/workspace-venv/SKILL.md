---
name: workspace-venv
description: |
  Default first-step skill for Python runtime setup.
  Trigger this skill when any of the following applies:
  - User asks for a Python execution environment.
  - User asks for virtual environment setup (venv/.venv).
  - User asks for Python interpreter setup.
  - User asks to make package installation ready.
  - User reports missing dependency/runtime errors
    (for example ModuleNotFoundError).
  Execute cross-platform workspace bootstrap with uv for
  macOS, Linux, and Windows: check uv availability, install uv only
  if missing, create a virtual environment with the latest available
  Python 3, activate it, and manage dependencies with
  separate dependency-only scripts using uv add/lock/sync.
---

# Workspace Venv

`uv` で workspace 単位の
Python 仮想環境を作成し、依存関係を minimal command で管理する。

Python の実行環境が必要な依頼では、
この skill を最初に実行する。

## Trigger Conditions

- Python 実行環境の準備を求められたとき
- `venv` / `.venv` の作成を求められたとき
- Python interpreter 設定を求められたとき
- package 導入準備（依存解決）を求められたとき
- `ModuleNotFoundError` など依存不足 error が出ているとき

## Scripts

Initial setup script:

```bash
# macOS
bash scripts/setup-macos.sh [workspace-dir]

# Linux
bash scripts/setup-linux.sh [workspace-dir]
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  [-WorkspaceDir <workspace-dir>]
```

Later dependency-only add script:

```bash
# macOS / Linux
bash scripts/add-deps.sh <workspace-dir> <pkg1> [pkg2...]
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  -WorkspaceDir <workspace-dir> `
  -Packages <pkg1>,<pkg2>
```

Dry run:

```bash
bash scripts/setup-macos.sh --dry-run [workspace-dir]
bash scripts/setup-linux.sh --dry-run [workspace-dir]
bash scripts/add-deps.sh --dry-run <workspace-dir> requests rich
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  [-WorkspaceDir <workspace-dir>] `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  -WorkspaceDir <workspace-dir> `
  -Packages requests,rich `
  -DryRun
```

## Workflow

1. setup 時の workspace を決める

`setup-*` script は `workspace-dir` 未指定時に
次の順で自動選択する。

- 現在 directory（`pyproject.toml` がある場合）
- Git root（Git 管理下の場合）
- 現在 directory

自動判定できない場合のみ、user 入力で path を受け取る。
実行時に `Workspace directory: <path>` を表示する。

1. `uv` が使えるか確認する

```bash
uv --version
```

1. `uv` が使えない場合のみ install する

```bash
# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass -c `
  "irm https://astral.sh/uv/install.ps1 | iex"
```

install 後は shell を再起動して
`uv --version` を実行する。

1. `uv` で最新 Python 3 系の仮想環境を作成する

```bash
uv venv --python 3 .venv
```

1. 仮想環境を有効化する

```bash
# macOS / Linux
source .venv/bin/activate
```

```powershell
# Windows PowerShell
.\.venv\Scripts\Activate.ps1
```

```cmd
:: Windows cmd
.venv\Scripts\activate.bat
```

1. 後から不足 library が見つかったら
   依存追加 script を使う

```bash
bash scripts/add-deps.sh <workspace-dir> <pkg1> [pkg2...]
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  -WorkspaceDir <workspace-dir> `
  -Packages <pkg1>,<pkg2>
```

## Rules

- すべての command は `pyproject.toml` がある
  workspace 直下で実行する。
- 依存追加は `pip install` ではなく `uv add` を優先する。
- 環境再現時は `uv sync` を実行してから
  activate する。
- script は最初に `uv --version` で確認し、
  `uv` がない場合のみ install する。
- setup 時の directory は自動選択し、
  選択した path を必ず表示する。
- 初期構築は `setup-*`、
  後追い依存追加は `add-deps.*` を使い分ける。
