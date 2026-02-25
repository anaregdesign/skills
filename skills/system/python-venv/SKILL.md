---
name: python-venv
description: |
  Default first-step skill for Python runtime setup and version switching with uv.
  Trigger this skill first whenever the conversation context requires Python
  script execution, package management, or dependency error handling.
  Manage per-version environments at `<skill-dir>/assets/vX.Y.Z/.venv`.
  Supports direct module execution (`--module`) and generated-code execution
  (`--code` / `--code-base64` / `--code-chunk`) by saving scripts into
  `<skill-dir>/assets/vX.Y.Z/src/` before running them.
  When asked to "write and run" Python, use generated-code mode instead of
  asking the user to create files manually.
  For MCP `skill_run_script`, one argument may be capped (for example 512 chars),
  so use repeated `--code-chunk` for longer scripts.
  If switched in the same shell, plain `python` uses the selected environment.
---

# Python Venv

`uv` で Python 実行環境を管理する。
Python 実行が必要な依頼では、この skill を最初に実行する。

## Trigger Conditions

- ユーザが Python 実行環境の準備を求めたとき
- ユーザが `venv` / `.venv` の作成を求めたとき
- ユーザが Python interpreter 設定や version 指定を求めたとき
- ユーザが package 導入準備（依存解決）を求めたとき
- 文脈上、Python Script の実行を求められたとき（他 skill が生成/保持する script 実行を含む）
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

Run Python in selected project env (script/module/generated code):

```bash
# macOS / Linux
bash scripts/run-python.sh [--python <version>] --script <abs-or-rel-path.py> [-- <script-args...>]
bash scripts/run-python.sh [--python <version>] --module <module.name> [-- <module-args...>]
bash scripts/run-python.sh [--python <version>] --code "<python-code>" [--name <generated.py>] [-- <script-args...>]
bash scripts/run-python.sh [--python <version>] --code-base64 <base64-python-code> [--name <generated.py>] [-- <script-args...>]
bash scripts/run-python.sh [--python <version>] --code-chunk "<part1>" --code-chunk "<part2>" [--name <generated.py>] [-- <script-args...>]
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass `
  -File scripts/run-python.ps1 `
  [-PythonVersion <version>] `
  (-ScriptPath <abs-or-rel-path.py> | -ModuleName <module.name> | -Code <python-code> | -CodeBase64 <base64-python-code> | -CodeChunk <part>) `
  [-GeneratedScriptName <generated.py>] `
  [-DryRun] `
  [-- <script-args...>]
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
- 依存: なし（初期ステップ）

### switch-python.*

- 役割: 既存の指定 version env を `deactivate -> activate` で切替える
- 入力: Python version（任意。未指定時は `assets/.env` の `PYTHON_VENV_ACTIVE_VERSION`）
- 出力:
  - `source` / dot-source 実行時: current shell の active env が指定 version に切替済み
  - 非 source 実行時: current shell は変更せず `assets/.env` の active 情報を更新
- 依存: `setup-*` で作成済みの `assets/vX.Y.Z/.venv`

### add-deps.*

- 役割: 依存追加のみ (`uv add -> uv lock -> uv sync`)
- 入力: Python version（任意。未指定時は `assets/.env` の `PYTHON_VENV_ACTIVE_VERSION`）, package list（必須）
- 出力: 指定 env の依存関係更新、`assets/vX.Y.Z/uv.lock` 更新
- 依存: `setup-*` で作成済みの `assets/vX.Y.Z/.venv` と `assets/vX.Y.Z/pyproject.toml`

### run-python.*

- 役割: 対象 version project の env で Python を実行する（`.py` 実行 / `-m module` 実行 / base64コード保存実行）
- 入力: `--script <path.py>` または `--module <module.name>` または `--code <python-code>` または `--code-base64 <base64>` または `--code-chunk <part>`（複数回指定可）
- 出力: 対象 mode で Python が実行され、必要時は `assets/vX.Y.Z/src/<name>.py` が生成される
- 依存: `setup-*` で作成済みの `assets/vX.Y.Z/.venv` と `assets/vX.Y.Z/pyproject.toml`

### remove-python.*

- 役割: 指定 version directory（`assets/vX.Y.Z`）を丸ごと削除する
- 入力: Python version（任意。未指定時は `assets/.env` の `PYTHON_VENV_ACTIVE_VERSION`）
- 出力: 指定 version の `.venv`/`pyproject.toml`/`uv.lock` が削除済み
- 依存: 対象 version directory が存在すること

Dry run:

```bash
bash scripts/setup-macos.sh --dry-run --python 3.12
bash scripts/setup-linux.sh --dry-run --python 3.12
bash scripts/switch-python.sh --dry-run
bash scripts/add-deps.sh --dry-run --python 3.12 requests rich
bash scripts/run-python.sh --dry-run --python 3.12 --script /abs/path/to/task.py -- --example arg
bash scripts/run-python.sh --dry-run --python 3.12 --module markitdown -- /abs/path/to/input.pptx
bash scripts/run-python.sh --dry-run --python 3.12 --code "print('hello')" --name hello.py
bash scripts/run-python.sh --dry-run --python 3.12 --code-base64 cHJpbnQoIkhlbGxvIikK --name hello.py
bash scripts/run-python.sh --dry-run --python 3.12 --code-chunk "print('hello')" --code-chunk "\nprint('world')" --name hello.py
bash scripts/remove-python.sh --dry-run
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/setup-windows.ps1 `
  -DryRun `
  [-PythonVersion 3.12]
powershell -ExecutionPolicy ByPass `
  -File scripts/switch-python.ps1 `
  [-PythonVersion 3.12] `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/add-deps.ps1 `
  [-PythonVersion 3.12] `
  -Packages requests,rich `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/run-python.ps1 `
  [-PythonVersion 3.12] `
  -ModuleName markitdown `
  -DryRun `
  -- C:\abs\path\to\input.pptx
powershell -ExecutionPolicy ByPass `
  -File scripts/run-python.ps1 `
  [-PythonVersion 3.12] `
  -Code "print('hello')" `
  -GeneratedScriptName hello.py `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/run-python.ps1 `
  [-PythonVersion 3.12] `
  -CodeBase64 cHJpbnQoIkhlbGxvIikK `
  -GeneratedScriptName hello.py `
  -DryRun
powershell -ExecutionPolicy ByPass `
  -File scripts/run-python.ps1 `
  [-PythonVersion 3.12] `
  -CodeChunk "print('hello')" `
  -CodeChunk "`nprint('world')" `
  -GeneratedScriptName hello.py `
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

### Step 2: `switch-python.*` で作業対象 version に切り替える

依存関係:
- Step 1 の成果物（`switch` は環境作成を行わない）

成果物:
- `source` / dot-source 実行時は current shell の `python` が対象 env を使う
- 非 source 実行時は `assets/.env` の active 情報が更新される

### Step 3: 不足 library があれば `add-deps.*` を実行する

依存関係:
- Step 1 の成果物（`assets/vX.Y.Z/.venv`, `assets/vX.Y.Z/pyproject.toml`）

成果物:
- `assets/vX.Y.Z/uv.lock` 更新
- 対象 env に依存が同期済み

### Step 4: `run-python.*` で実行する（script/module/generated code）

依存関係:
- Step 1
- 必要に応じて Step 3

実行ルール:
- `.py` 実行時は `--script` を使い、配置済み path をそのまま使う（絶対 path 推奨）
- Python module実行時は `--module` を使う（`python -m` 相当）
- ワンライナー/短いコードは `--code`（PowerShellは `-Code`）を使う
- 生成コード実行時は `--code-base64` を使う（必要なら `--name` でファイル名を指定）
- 長いコードでMCP引数長制限に当たる場合は `--code-chunk`（PowerShellは `-CodeChunk`）を複数回使う

同一 shell で `python` 実行する場合（Step 2 を source 済み）:

```bash
source scripts/switch-python.sh --python 3.12.10
python /abs/path/to/script.py
```

非対話実行（MCP / 別プロセス）で確実に env 指定する場合:

```bash
bash scripts/run-python.sh --python 3.12.10 --script /abs/path/to/script.py -- --arg1 value1
bash scripts/run-python.sh --python 3.12.10 --module markitdown -- /abs/path/to/slides.pptx
bash scripts/run-python.sh --python 3.12.10 --code "print('hello world')" --name hello_world.py
bash scripts/run-python.sh --python 3.12.10 --code-base64 cHJpbnQoImhlbGxvIHdvcmxkIikK --name hello_world.py
bash scripts/run-python.sh --python 3.12.10 --code-chunk "import sys\n" --code-chunk "print(sys.version)\n" --name hello_world.py
```

```powershell
powershell -ExecutionPolicy ByPass `
  -File scripts/run-python.ps1 `
  -PythonVersion 3.12.10 `
  -ScriptPath C:\abs\path\to\script.py `
  -- --arg1 value1
powershell -ExecutionPolicy ByPass `
  -File scripts/run-python.ps1 `
  -PythonVersion 3.12.10 `
  -ModuleName markitdown `
  -- C:\abs\path\to\slides.pptx
powershell -ExecutionPolicy ByPass `
  -File scripts/run-python.ps1 `
  -PythonVersion 3.12.10 `
  -Code "print('hello world')" `
  -GeneratedScriptName hello_world.py
powershell -ExecutionPolicy ByPass `
  -File scripts/run-python.ps1 `
  -PythonVersion 3.12.10 `
  -CodeBase64 cHJpbnQoImhlbGxvIHdvcmxkIikK `
  -GeneratedScriptName hello_world.py
powershell -ExecutionPolicy ByPass `
  -File scripts/run-python.ps1 `
  -PythonVersion 3.12.10 `
  -CodeChunk "import sys`n" `
  -CodeChunk "print(sys.version)`n" `
  -GeneratedScriptName hello_world.py
```

コンテキスト内で生成された script text を実行する場合:
- 1行程度のコードなら `run-python.*` の `--code`（PowerShellは `-Code`）を使う
- `run-python.*` の `--code-base64`（PowerShellは `-CodeBase64`）で直接実行できる
- 長文コードは `run-python.*` の `--code-chunk`（PowerShellは `-CodeChunk`）を複数回指定して保存してから実行する
- 生成ファイル名を固定したい場合のみ `--name` / `-GeneratedScriptName` を使う

### Step 5: 環境破損時は `remove-python.*` の後に `setup-*` で再作成し、必要なら `switch-python.*` で切替える

依存関係:
- 対象 env が active でないこと（先に deactivate）

## Rules

- Python env の path は `<skill-dir>/assets/vX.Y.Z/.venv` に統一する。
- version ごとに project と依存を分離する。
- `assets/vX.Y.Z/pyproject.toml` と `assets/vX.Y.Z/uv.lock` で管理する。
- setup/switch/add/remove/run はこの skill の scripts を使う。
- `setup-*` は環境作成/同期のみ、`switch-python.*` は切替のみ、`add-deps.*` は依存追加のみ、`run-python.*` は実行のみ、`remove-python.*` は削除のみを担当する。
- setup/switch/add/remove/run 実行時に cwd を変更しない。
- 重要な環境変数は `assets/.env` に永続化し、各 script は `assets/.env` を参照する。
- 非 source の `switch-python.*` は current shell を変更しない。
- current shell で通常 `python` を使いたい場合は `switch-python.*` を source / dot-source で実行する。
- 非対話実行では `run-python.*` により `uv --project <project> run python ...` を使って対象 project env を明示する。
- `run-python.*` の実行モード（script/module/code/code-base64/code-chunk）は1つだけ指定する。
- `run-python.*` でインライン実行が必要な場合は `--code` / `--code-base64` を使い、`--script -c` や `--script -` は使わない。
- MCPの `skill_run_script` では1引数の長さ制限に注意し、長いコードは `--code-chunk` で分割して渡す。
- 生成コードは必ず `assets/vX.Y.Z/src/<name>.py` に保存してから実行する（直接 `--script -c` 方式は使わない）。
- `skill_run_script` の `path` には `scripts/<file>` だけを渡す（`../` を含めない）。外部 script path は `args` で渡す。
- 実行時の path は絶対 path を優先する。
- `add-deps.*` はこの skill が作成した env（`<skill-dir>/assets/vX.Y.Z/.venv`）だけを対象にする。
- `remove-python.*` は指定した `assets/vX.Y.Z` だけを削除対象にする。
- active な env は削除しない（先に deactivate してから削除する）。
