---
name: python-venv
description: |
  Default first-step skill for Python runtime setup and version switching with uv.
  Trigger this skill first whenever the conversation context requires Python
  execution, package management, or dependency error handling.
  Manage per-version environments at `<skill-dir>/assets/vX.Y.Z/.venv`.
---

# Python Venv

`uv` で Python 実行環境を管理する。
Python 環境が必要な依頼では、この skill を最初に実行する。

## Trigger Conditions

- ユーザが Python 実行環境の準備を求めたとき
- ユーザが `venv` / `.venv` の作成を求めたとき
- ユーザが Python interpreter 設定や version 指定を求めたとき
- ユーザが package 導入準備（依存解決）を求めたとき
- `ModuleNotFoundError` など依存不足 error が出ているとき
- 同じ version の env で runtime/import error が頻発しているとき
- ユーザが明示していなくても、次の手順で Python 実行が必要だと判断できるとき
- `python`, `pytest`, `uv run`, `uv add`, `pip` など Python/package 系 command 実行が必要なとき
- 上記に該当する場合は、必ずこの skill を先に呼び出してから本作業に進む

## Scripts

Initial setup script:

```bash
# macOS
bash scripts/setup-macos.sh [--python <version>] [--dry-run]

# Linux
bash scripts/setup-linux.sh [--python <version>] [--dry-run]
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  [-PythonVersion <version>] `
  [-DryRun]
```

Later dependency-only add script:

```bash
# macOS / Linux
bash scripts/add-deps.sh [--dry-run] <pkg1> [pkg2...]
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  -Packages <pkg1>,<pkg2> `
  [-DryRun]
```

Version switch script:

```bash
# macOS / Linux (must run with source)
source scripts/switch-python.sh --python <version>
source scripts/switch-python.sh --dry-run --python <version>
```

```powershell
# Windows PowerShell (must run with dot-source)
. .\scripts\switch-python.ps1 `
  -PythonVersion <version> `
  [-DryRun]
```

Version remove script:

```bash
# macOS / Linux
bash scripts/remove-python.sh --python <x.y.z>
bash scripts/remove-python.sh --dry-run --python <x.y.z>
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass `
  -File scripts/remove-python.ps1 `
  -PythonVersion <x.y.z> `
  [-DryRun]
```

## Dependency Map

### setup-*

- 役割: `uv` の確認/導入、指定 Python の env 作成/同期
- 入力: Python version (任意)
- 出力: `<skill-dir>/assets/vX.Y.Z/.venv`
- 依存: `uv`, `assets/vX.Y.Z/pyproject.toml`（version ごとに `uv init --bare` で管理）

### switch-python.*

- 役割: 指定 version の env がなければ作成し、`deactivate -> activate`
- 入力: Python version（必須）
- 出力: current shell の active env が指定 version に切替済み
- 依存: `setup-*` と同じ基盤。Bash は `source`、PowerShell は dot-source 必須

### add-deps.*

- 役割: 依存追加のみ (`uv add -> uv lock -> uv sync`)
- 入力: package list（必須）
- 出力: 指定 env の依存関係更新
- 依存: 既存 env と version project（`assets/vX.Y.Z/.venv` と `assets/vX.Y.Z/pyproject.toml`）

### remove-python.*

- 役割: 指定 version directory（`assets/vX.Y.Z`）を丸ごと削除する
- 入力: Python version（必須、`x.y.z`）
- 出力: 指定 version の `.venv`/`pyproject.toml`/`uv.lock` が削除済み
- 依存: 対象 version directory が存在すること

Dry run:

```bash
bash scripts/setup-macos.sh --dry-run --python 3.12
bash scripts/setup-linux.sh --dry-run --python 3.12
bash scripts/add-deps.sh --dry-run requests rich
bash scripts/switch-python.sh --dry-run --python 3.12
bash scripts/remove-python.sh --dry-run --python 3.12.10
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  -DryRun `
  [-PythonVersion 3.12]
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  -Packages requests,rich `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/switch-python.ps1 `
  -PythonVersion 3.12 `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/remove-python.ps1 `
  -PythonVersion 3.12.10 `
  -DryRun
```

## Workflow

### Step 1: `uv` が使えるか確認する

```bash
uv --version
```

### Step 2: `uv` が使えない場合のみ install する

```bash
# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass -c `
  "irm https://astral.sh/uv/install.ps1 | iex"
```

### Step 3: 要求された Python version の env を作成する

作成先は必ず次の固定 path にする。

- `<skill-dir>/assets/vX.Y.Z/.venv`

要求 version が既存 env にない場合は新規作成する。
同じ version が既にある場合は再作成せずに再利用する。

```bash
uv venv --python <resolved-python> \
  <skill-dir>/assets/vX.Y.Z/.venv
```

### Step 4: `assets/vX.Y.Z` に移動して project を初期化/同期する

```bash
uv --directory <skill-dir>/assets/vX.Y.Z init --bare --python <resolved-python>
env -u VIRTUAL_ENV UV_PROJECT_ENVIRONMENT=<skill-dir>/assets/vX.Y.Z/.venv \
  uv --project <skill-dir>/assets/vX.Y.Z sync --python <resolved-python>
```

### Step 5: 現在 env を deactivate して要求 version を activate する

```bash
source scripts/switch-python.sh --python <version>
```

```powershell
. .\scripts\switch-python.ps1 -PythonVersion <version>
```

### Step 6: 後から不足 library が見つかったら依存追加 script を使う

```bash
bash scripts/add-deps.sh <pkg1> [pkg2...]
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  -Packages <pkg1>,<pkg2>
```

### Step 7: 環境が壊れた version は丸ごと削除して作り直す

同じ version で error が頻発するときは、個別修復より先にこの手順を使う。
指定 version の `assets/vX.Y.Z` を削除し、`setup-*` か
`switch-python.*` で再作成する。

```bash
bash scripts/remove-python.sh --python 3.12.10
bash scripts/setup-macos.sh --python 3.12.10
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/remove-python.ps1 `
  -PythonVersion 3.12.10
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  -PythonVersion 3.12.10
```

## Rules

- `pyproject` は version ごとに `assets/vX.Y.Z/pyproject.toml` を使う（別 version は別 project）。
- `pyproject` の拡張子は `.toml`（`pyproject.yaml` ではない）。
- Python env の path は必ず `<skill-dir>/assets/vX.Y.Z/.venv` に統一する。
- `assets/` が存在しない場合は script が自動作成し、directory 不在では失敗しない。
- `uv` command は必ず `assets/` 配下（基本は `assets/vX.Y.Z`）で実行する。
- 依存関係と lockfile は version ごとに分離する。
- `assets/vX.Y.Z/pyproject.toml` と `assets/vX.Y.Z/uv.lock` に保存する。
- 別バージョン要求時は新しい `vX.Y.Z/.venv` を作成する。
- 同じ version の env が存在する場合は再作成しない。
- version 切替時は current env を deactivate してから activate する。
- PowerShell の version 切替は dot-source で実行する。
- dependency 追加は `pip install` ではなく `uv add` を優先する。
- `add-deps.*` はこの skill が作成した env（`<skill-dir>/assets/vX.Y.Z/.venv`）だけを対象にする。
- `remove-python.*` は指定した `assets/vX.Y.Z` だけを削除対象にする。
- active な env は削除しない（先に deactivate してから削除する）。
- 後方互換や fallback は実装しない。最新の運用フローだけをサポートする。
