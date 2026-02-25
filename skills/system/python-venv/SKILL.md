---
name: python-venv
description: |
  Default first-step skill for Python runtime setup.
  Even when the user does not explicitly request environment setup,
  trigger this skill first whenever the conversation context implies
  Python execution is required.
  Trigger this skill when any of the following applies:
  - A Python execution environment is required for the next step.
  - Virtual environment setup (venv/.venv) is required.
  - Python interpreter setup or version alignment is required.
  - Package installation or dependency resolution is required.
  - A specific Python version is required (for example 3.12.10).
  - Dependency/runtime errors are present (for example ModuleNotFoundError).
  - The next task step requires running Python/package commands in the terminal.
  Execute cross-platform workspace bootstrap with uv for macOS,
  Linux, and Windows. Always place environments at
  `<skill-dir>/assets/vX.Y.Z/.venv`.
  If a different Python version is requested, create that version's
  environment, then deactivate the current environment and activate the
  requested one.
---

# Python Venv

`uv` で workspace 単位の Python 実行環境を管理する。

Python 実行環境が必要な依頼では、この skill を最初に使う。

## Trigger Conditions

- Python 実行環境の準備を求められたとき
- `venv` / `.venv` の作成を求められたとき
- Python interpreter 設定を求められたとき
- package 導入準備（依存解決）を求められたとき
- Python の特定バージョンを要求されたとき
- `ModuleNotFoundError` など依存不足 error が出ているとき
- ユーザが明示していなくても、対話の次の手順で Python 実行が必要だと判断できるとき
- `python`, `pytest`, `uv run`, `uv add`, `pip` など Python/package 系 command の実行が必要になるとき
- 上記に該当する場合は、必ずこの skill を先に呼び出してから本作業に進む

## Scripts

Initial setup script:

```bash
# macOS
bash scripts/setup-macos.sh [--python <version>] [workspace-dir]

# Linux
bash scripts/setup-linux.sh [--python <version>] [workspace-dir]
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  [-PythonVersion <version>] `
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

Version switch script:

```bash
# macOS / Linux (must run with source)
source scripts/switch-python.sh --python <version> [--workspace <workspace-dir>]
```

```powershell
# Windows PowerShell (must run with dot-source)
. .\scripts\switch-python.ps1 `
  -PythonVersion <version> `
  [-WorkspaceDir <workspace-dir>]
```

## Dependency Map

1. `setup-*`

- 役割: `uv` の確認/導入、workspace 準備、指定 Python の env 作成/同期
- 入力: `workspace-dir` (任意), Python version (任意)
- 出力: `<skill-dir>/assets/vX.Y.Z/.venv`
- 依存: `uv`, `pyproject.toml`（なければ `uv init` で作成）

1. `switch-python.*`

- 役割: 指定 version の env がなければ作成し、`deactivate -> activate`
- 入力: Python version（必須）, `workspace-dir`（任意）
- 出力: current shell の active env が指定 version に切替済み
- 依存: `setup-*` と同じ基盤。Bash は `source`、PowerShell は dot-source 必須

1. `add-deps.*`

- 役割: 依存追加のみ (`uv add -> uv lock -> uv sync`)
- 入力: `workspace-dir`（必須）, package list（必須）
- 出力: 指定 env の依存関係更新
- 依存: 既存 env（`setup-*` / `switch-python.*` で作成済み）

Dry run:

```bash
bash scripts/setup-macos.sh --dry-run --python 3.12 [workspace-dir]
bash scripts/setup-linux.sh --dry-run --python 3.12 [workspace-dir]
bash scripts/add-deps.sh --dry-run <workspace-dir> requests rich
bash scripts/switch-python.sh --dry-run --python 3.12 --workspace <workspace-dir>
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  -DryRun `
  [-PythonVersion 3.12] `
  [-WorkspaceDir <workspace-dir>]
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  -WorkspaceDir <workspace-dir> `
  -Packages requests,rich `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/switch-python.ps1 `
  -PythonVersion 3.12 `
  [-WorkspaceDir <workspace-dir>] `
  -DryRun
```

## Workflow

1. setup 対象の workspace を決める

`setup-*` は `workspace-dir` 未指定時に次の順で自動選択する。

- 現在 directory（`pyproject.toml` がある場合）
- Git root（Git 管理下の場合）
- 現在 directory

自動判定できない場合のみ、user 入力で path を受け取る。

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

1. 要求された Python バージョンで env を作成する

作成先は必ず次の固定パスにする。

- `<skill-dir>/assets/vX.Y.Z/.venv`

要求バージョンが既存 env にない場合は新規作成する。
同じ version が既にある場合は再作成せずに再利用する。

```bash
uv venv --python <resolved-python> \
  <skill-dir>/assets/vX.Y.Z/.venv
```

1. 現在 env を deactivate して要求バージョンを activate する

```bash
source scripts/switch-python.sh --python <version> [--workspace <workspace-dir>]
```

```powershell
. .\scripts\switch-python.ps1 `
  -PythonVersion <version> `
  [-WorkspaceDir <workspace-dir>]
```

1. 後から不足 library が見つかったら依存追加 script を使う

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

- すべての command は `pyproject.toml` がある workspace で実行する。
- Python env の path は必ず `<skill-dir>/assets/vX.Y.Z/.venv` に統一する。
- `assets/` が存在しない場合は script が自動作成し、directory 不在では失敗しない。
- `uv` command は必ず `assets/` 配下（基本は `assets/vX.Y.Z`）に `cd` してから実行する。
- 別バージョン要求時は新しい `vX.Y.Z/.venv` を作成する。
- 同じ version の env が存在する場合は再作成しない。
- version 切替時は current env を deactivate してから activate する。
- PowerShell の version 切替は dot-source で実行する。
- dependency 追加は `pip install` ではなく `uv add` を優先する。
- `add-deps.*` は active なこの skill 配下の env を優先して使う。
