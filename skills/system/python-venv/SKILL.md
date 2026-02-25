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
bash scripts/add-deps.sh [--dry-run] [--python <version>] <pkg1> [pkg2...]
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  [-PythonVersion <version>] `
  -Packages <pkg1>,<pkg2> `
  [-DryRun]
```

Version switch script:

```bash
# macOS / Linux
source scripts/switch-python.sh [--python <version>]
bash scripts/switch-python.sh [--python <version>]
source scripts/switch-python.sh --dry-run [--python <version>]
```

```powershell
# Windows PowerShell
. .\scripts\switch-python.ps1 `
  [-PythonVersion <version>] `
  [-DryRun]
powershell -ExecutionPolicy ByPass `
  -File scripts/switch-python.ps1 `
  [-PythonVersion <version>] `
  [-DryRun]
```

Version remove script:

```bash
# macOS / Linux
bash scripts/remove-python.sh [--python <x.y.z>]
bash scripts/remove-python.sh --dry-run [--python <x.y.z>]
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass `
  -File scripts/remove-python.ps1 `
  [-PythonVersion <x.y.z>] `
  [-DryRun]
```

Generated script save+run helper (MCP `skill_run_script` 用):

```bash
# macOS / Linux
bash scripts/run-generated.sh \
  [--python <version>] \
  --name <file.py> \
  --code-base64 <base64-python-code>
```

`assets/.env` に以下を永続化し、全 script が参照する:
- `PYTHON_VENV_SKILL_DIR`
- `PYTHON_VENV_ASSETS_DIR`
- `PYTHON_VENV_ACTIVE_VERSION`
- `PYTHON_VENV_ACTIVE_PROJECT_DIR`
- `PYTHON_VENV_ACTIVE_VENV_DIR`
- `PYTHON_VENV_ACTIVE_PYTHON_BIN`
- `PYTHON_VENV_LAST_ACTION`

`--python` を省略できるのは、`assets/.env` に `PYTHON_VENV_ACTIVE_VERSION` がある場合のみ。

## Dependency Map

### setup-*

- 役割: `uv` の確認/導入、指定 Python の env 作成/同期
- 入力: Python version (任意)
- 出力: `assets/vX.Y.Z/.venv`, `assets/vX.Y.Z/pyproject.toml`, `assets/vX.Y.Z/uv.lock`, `assets/vX.Y.Z/src/`
- 依存: `uv`（なければ setup 内で導入）

### switch-python.*

- 役割: 既存の指定 version env を `deactivate -> activate` で切替える
- 入力: Python version（任意。未指定時は `assets/.env` の `PYTHON_VENV_ACTIVE_VERSION`）
- 出力:
  - `source` / dot-source 実行時: current shell の active env が指定 version に切替済み
  - 非 source 実行時: current shell は変更せず `assets/.env` の active 情報を更新
  - `assets/vX.Y.Z/src/` が利用可能
- 依存: `setup-*` で作成済みの `assets/vX.Y.Z/.venv`

### add-deps.*

- 役割: 依存追加のみ (`uv add -> uv lock -> uv sync`)
- 入力: Python version（任意。未指定時は `assets/.env` の `PYTHON_VENV_ACTIVE_VERSION`）, package list（必須）
- 出力: 指定 env の依存関係更新、`assets/vX.Y.Z/uv.lock` 更新
- 依存: `setup-*` で作成済みの `assets/vX.Y.Z/.venv` と `assets/vX.Y.Z/pyproject.toml`

### uv run python

- 役割: 生成された Python script を、対象 version project の env で実行する
- 入力: `assets/vX.Y.Z/src/` 配下の script path（`hello.py` など）
- 出力: script が `assets/vX.Y.Z/.venv` を使って実行される
- 依存: `setup-*` または `switch-python.*` により作成済みの `assets/vX.Y.Z/.venv` と `assets/vX.Y.Z/pyproject.toml`

### remove-python.*

- 役割: 指定 version directory（`assets/vX.Y.Z`）を丸ごと削除する
- 入力: Python version（任意。未指定時は `assets/.env` の `PYTHON_VENV_ACTIVE_VERSION`）
- 出力: 指定 version の `.venv`/`pyproject.toml`/`uv.lock` が削除済み
- 依存: 対象 version directory が存在すること

### run-generated.sh

- 役割: 生成 Python script を `assets/vX.Y.Z/src/` に保存し、`uv --project ... run python ...` で実行する
- 入力: Python version（任意。未指定時は `assets/.env` の `PYTHON_VENV_ACTIVE_VERSION`）, script名（必須）, base64化済みPythonコード（必須）
- 出力: `assets/vX.Y.Z/src/<name>.py` が保存され、対象envで実行される
- 依存: `setup-*` で作成済みの `assets/vX.Y.Z/.venv` と `assets/vX.Y.Z/pyproject.toml`

Dry run:

```bash
bash scripts/setup-macos.sh --dry-run --python 3.12
bash scripts/setup-linux.sh --dry-run --python 3.12
bash scripts/add-deps.sh --dry-run --python 3.12 requests rich
bash scripts/switch-python.sh --dry-run
bash scripts/remove-python.sh --dry-run
bash scripts/run-generated.sh --dry-run --python 3.12 --name hello.py --code-base64 cHJpbnQoIkhlbGxvIikK
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  -DryRun `
  [-PythonVersion 3.12]
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  [-PythonVersion 3.12] `
  -Packages requests,rich `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/switch-python.ps1 `
  [-PythonVersion 3.12] `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/remove-python.ps1 `
  [-PythonVersion 3.12.10] `
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
- Step 1 の成果物（`switch` は環境作成を行わない）

成果物:
- current shell の active env が対象 version に切替済み
- `assets/vX.Y.Z/src/` が利用可能

### Step 3: 生成 script を `assets/vX.Y.Z/src/` へ配置し、`uv run python` で実行する

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
uv --project "${PROJECT_DIR}" run python "${SCRIPT_PATH}"
```

```powershell
$projectDir = "<skill-dir>\assets\v3.12.10"
$scriptPath = "$projectDir\src\generated.py"
Copy-Item C:\path\to\generated.py $scriptPath
uv --project $projectDir run python $scriptPath
```

MCP `skill_run_script` で「保存 + 実行」を1回で行う場合の例:

```bash
CODE_BASE64="$(printf 'print(\"hello from generated script\")\n' | base64 | tr -d '\n')"
bash scripts/run-generated.sh --python 3.12.10 --name generated.py --code-base64 "${CODE_BASE64}"
```

コンテキスト内で生成された script を保存して実行する例:

```bash
PROJECT_DIR="<skill-dir>/assets/v3.12.10"
SCRIPT_PATH="${PROJECT_DIR}/src/generated.py"
cat > "${SCRIPT_PATH}" <<'PY'
print("hello from generated script")
PY
uv --project "${PROJECT_DIR}" run python "${SCRIPT_PATH}"
```

```powershell
$projectDir = "<skill-dir>\assets\v3.12.10"
$scriptPath = "$projectDir\src\generated.py"
@'
print("hello from generated script")
'@ | Set-Content $scriptPath -Encoding UTF8
uv --project $projectDir run python $scriptPath
```

### Step 4: 不足 library があれば `add-deps.*` を実行する

依存関係:
- Step 1 の成果物（`assets/vX.Y.Z/.venv`, `assets/vX.Y.Z/pyproject.toml`）

成果物:
- `assets/vX.Y.Z/uv.lock` 更新
- 対象 env に依存が同期済み

実行例:

```bash
bash scripts/add-deps.sh --python 3.12 requests rich
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  -PythonVersion 3.12 `
  -Packages requests,rich
```

### Step 5: 環境破損時は `remove-python.*` の後に `setup-*` で再作成し、必要なら `switch-python.*` で切替える

依存関係:
- 対象 env が active でないこと（先に deactivate）

## Rules

- Python env の path は必ず `<skill-dir>/assets/vX.Y.Z/.venv` に統一する。
- version ごとに project と依存を分離する。
- `assets/vX.Y.Z/pyproject.toml` と `assets/vX.Y.Z/uv.lock` で管理する。
- setup/switch/add/remove はこの skill の scripts を使う。
- `setup-*` は環境作成/同期のみ、`switch-python.*` は切替のみ、`add-deps.*` は依存追加のみ、`remove-python.*` は削除のみを担当する。
- `run-generated.sh` は保存と実行のみを担当する。
- `switch-python.*` を非 source 実行した場合は `assets/.env` の active 更新のみ行い、現在 shell の `python` は切り替わらない。
- setup/switch/add/remove 実行時に cwd を変更しない。
- 重要な環境変数は `assets/.env` に永続化し、各 script は `assets/.env` を参照する。
- 生成 script は必ず `assets/vX.Y.Z/src/` に配置する。
- 生成 script の実行は必ず `uv --project <abs-project-path> run python <abs-script-path>` を使い、対象 project の env（`assets/vX.Y.Z/.venv`）を使用する。
- 実行時の path は相対 path ではなく絶対 path を優先する。
- `add-deps.*` はこの skill が作成した env（`<skill-dir>/assets/vX.Y.Z/.venv`）だけを対象にする。
- `remove-python.*` は指定した `assets/vX.Y.Z` だけを削除対象にする。
- active な env は削除しない（先に deactivate してから削除する）。
