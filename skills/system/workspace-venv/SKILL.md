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

`uv` でワークスペース単位の
Python 仮想環境を作成し、依存関係を最小コマンドで管理する。

Python の実行環境が必要な依頼では、
このスキルを最初に実行する。

## Trigger Conditions

- Python 実行環境の準備を求められたとき
- `venv` / `.venv` の作成を求められたとき
- Python インタープリタ設定を求められたとき
- パッケージ導入準備（依存解決）を求められたとき
- `ModuleNotFoundError` など依存不足エラーが出ているとき

## Scripts

初期セットアップ用スクリプト:

```bash
# macOS
bash scripts/setup-macos.sh <workspace-dir>

# Linux
bash scripts/setup-linux.sh <workspace-dir>
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  -WorkspaceDir <workspace-dir>
```

後から不足依存だけを追加するスクリプト:

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

ドライラン:

```bash
bash scripts/setup-macos.sh --dry-run <workspace-dir>
bash scripts/setup-linux.sh --dry-run <workspace-dir>
bash scripts/add-deps.sh --dry-run <workspace-dir> requests rich
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  -WorkspaceDir <workspace-dir> `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  -WorkspaceDir <workspace-dir> `
  -Packages requests,rich `
  -DryRun
```

## Workflow

1. 作成するディレクトリを選ぶ

```bash
# macOS / Linux
mkdir -p <workspace-dir>
cd <workspace-dir>
```

```powershell
# Windows PowerShell
New-Item -ItemType Directory -Path <workspace-dir> -Force
Set-Location <workspace-dir>
```

```cmd
:: Windows cmd
mkdir <workspace-dir>
cd <workspace-dir>
```

必要なら `uv init` を実行して `pyproject.toml` を作成する。

1. `uv` が使えるか確認する

```bash
uv --version
```

1. `uv` が使えない場合のみインストールする

```bash
# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass -c `
  "irm https://astral.sh/uv/install.ps1 | iex"
```

インストール後はシェルを再起動して
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

1. 後から不足ライブラリが見つかったら
   依存追加スクリプトを使う

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

- すべてのコマンドは `pyproject.toml` がある
  ワークスペース直下で実行する。
- 依存追加は `pip install` ではなく `uv add` を優先する。
- 環境再現時は `uv sync` を実行してから
  アクティベートする。
- スクリプトは最初に `uv --version` で確認し、
  `uv` がない場合のみインストールする。
- 初期構築は `setup-*`、
  後追い依存追加は `add-deps.*` を使い分ける。
