---
name: python-venv
description: |
  Default first-step skill for Python runtime setup and version switching with uv.
  Trigger this skill first whenever the conversation context requires Python
  execution, package management, or dependency error handling.
  Manage per-version environments at `<skill-dir>/assets/vX.Y.Z/.venv`.
  Generated scripts must be placed under `<skill-dir>/assets/vX.Y.Z/src` and run
  with `uv --project <project-dir> run python <script-path>`.
---

# Python Venv

`uv` で Python 実行環境を管理する。
Python 環境が必要な依頼では、この skill を最初に実行する。

## Trigger Conditions

- ユーザが Python 実行環境の準備を求めたとき
- ユーザが `venv` / `.venv` の作成を求めたとき
- ユーザが Python interpreter 設定や version 指定を求めたとき
- ユーザが package 導入準備（依存解決）を求めたとき
- 文脈上、Python Script の実行を求められたとき（生成 script 実行を含む）
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
- 出力: `assets/vX.Y.Z/.venv`, `assets/vX.Y.Z/pyproject.toml`, `assets/vX.Y.Z/uv.lock`, `assets/vX.Y.Z/src/`
- 依存: `uv`（なければ setup 内で導入）

### switch-python.*

- 役割: 指定 version の env がなければ作成し、`deactivate -> activate`
- 入力: Python version（必須）
- 出力: current shell の active env が指定 version に切替済み、`assets/vX.Y.Z/src/`、cwd は変更しない
- 依存: `setup-*` の成果物を再利用（不足時は同等成果物を自動作成）。Bash は `source`、PowerShell は dot-source 必須

### add-deps.*

- 役割: 依存追加のみ (`uv add -> uv lock -> uv sync`)
- 入力: package list（必須）
- 出力: 指定 env の依存関係更新、`assets/vX.Y.Z/uv.lock` 更新
- 依存: `setup-*` または `switch-python.*` により作成済みの `assets/vX.Y.Z/.venv` と `assets/vX.Y.Z/pyproject.toml`

### uv run python

- 役割: 生成された Python script を、対象 version project の env で実行する
- 入力: `assets/vX.Y.Z/src/` 配下の script path（`hello.py` など）
- 出力: script が `assets/vX.Y.Z/.venv` を使って実行される
- 依存: `setup-*` または `switch-python.*` により作成済みの `assets/vX.Y.Z/.venv` と `assets/vX.Y.Z/pyproject.toml`

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

### Step 1: `setup-*` で version project を作成する

依存関係:
- なし（初期ステップ）

成果物:
- `assets/vX.Y.Z/.venv`
- `assets/vX.Y.Z/pyproject.toml`
- `assets/vX.Y.Z/uv.lock`
- `assets/vX.Y.Z/src/`

### Step 2: `switch-python.*` で作業対象 version に切り替える

依存関係:
- Step 1 の成果物（不足時は `switch` が自動補完）

成果物:
- current shell の active env が対象 version に切替済み
- `assets/vX.Y.Z/src/` が利用可能
- current shell の cwd は維持される

### Step 3: 生成 script を `assets/vX.Y.Z/src/`（= `../vX.Y.Z/src/`）へ配置し、`uv run python` で実行する

依存関係:
- Step 1 または Step 2 による `assets/vX.Y.Z/.venv`
- Step 1 または Step 2 による `assets/vX.Y.Z/pyproject.toml`

実行ルール:
- cwd に依存しないよう、`--project` と script path は絶対 path で指定する

実行例:

```bash
PROJECT_DIR="<skill-dir>/assets/v3.12.10"
SCRIPT_PATH="${PROJECT_DIR}/src/generated.py"
cp /path/to/generated.py "${SCRIPT_PATH}"
env -u VIRTUAL_ENV UV_PROJECT_ENVIRONMENT="${PROJECT_DIR}/.venv" \
  uv --project "${PROJECT_DIR}" run python "${SCRIPT_PATH}"
```

```powershell
$projectDir = "<skill-dir>\assets\v3.12.10"
$scriptPath = "$projectDir\src\generated.py"
Copy-Item C:\path\to\generated.py $scriptPath
$env:UV_PROJECT_ENVIRONMENT = "$projectDir\.venv"
try {
  Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
  uv --project $projectDir run python $scriptPath
}
finally {
  Remove-Item Env:UV_PROJECT_ENVIRONMENT -ErrorAction SilentlyContinue
}
```

コンテキスト内で生成された script を保存して実行する例:

```bash
PROJECT_DIR="<skill-dir>/assets/v3.12.10"
SCRIPT_PATH="${PROJECT_DIR}/src/generated.py"
cat > "${SCRIPT_PATH}" <<'PY'
print("hello from generated script")
PY
env -u VIRTUAL_ENV UV_PROJECT_ENVIRONMENT="${PROJECT_DIR}/.venv" \
  uv --project "${PROJECT_DIR}" run python "${SCRIPT_PATH}"
```

```powershell
$projectDir = "<skill-dir>\assets\v3.12.10"
$scriptPath = "$projectDir\src\generated.py"
@'
print("hello from generated script")
'@ | Set-Content $scriptPath -Encoding UTF8
$env:UV_PROJECT_ENVIRONMENT = "$projectDir\.venv"
try {
  Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
  uv --project $projectDir run python $scriptPath
}
finally {
  Remove-Item Env:UV_PROJECT_ENVIRONMENT -ErrorAction SilentlyContinue
}
```

### Step 4: 不足 library があれば `add-deps.*` を実行する

依存関係:
- Step 1 または Step 2 の成果物

成果物:
- `assets/vX.Y.Z/uv.lock` 更新
- 対象 env に依存が同期済み

### Step 5: 環境破損時は `remove-python.*` の後に `setup-*` または `switch-python.*` で再作成する

依存関係:
- 対象 env が active でないこと（先に deactivate）

## Rules

- Python env の path は必ず `<skill-dir>/assets/vX.Y.Z/.venv` に統一する。
- version ごとに project と依存を分離する。
- `assets/vX.Y.Z/pyproject.toml` と `assets/vX.Y.Z/uv.lock` で管理する。
- setup/switch/add/remove はこの skill の scripts を使う。
- setup/switch/add/remove 実行時に cwd を変更しない。
- 生成 script は必ず `assets/vX.Y.Z/src/` に配置する。
- 生成 script の実行は必ず `uv --project <abs-project-path> run python <abs-script-path>` を使い、対象 project の env（`assets/vX.Y.Z/.venv`）を使用する。
- 実行時の path は相対 path ではなく絶対 path を優先する。
- `add-deps.*` はこの skill が作成した env（`<skill-dir>/assets/vX.Y.Z/.venv`）だけを対象にする。
- `remove-python.*` は指定した `assets/vX.Y.Z` だけを削除対象にする。
- active な env は削除しない（先に deactivate してから削除する）。
