---
name: python-venv
description: |
  Default first-step skill for Python runtime setup with uv.
  Use this before Python script execution or dependency installation.
  Manage per-version envs under `<skill-dir>/assets/vX.Y.Z/.venv`.
  This skill assumes thread-level environment sharing is available:
  once `source <venv>/bin/activate` is run, subsequent `python ...`
  commands in the same thread use that environment.
---

# Python Venv

`uv` で Python 実行環境を作成・切り替えする。
この skill は「環境を作る/切り替える」ことに集中し、実行は基本 `python ...` を使う。

## Trigger Conditions

- Python 実行環境の準備が必要
- `.venv` 作成や Python version 指定が必要
- `ModuleNotFoundError` など依存不足エラーが出た
- `python` / `pytest` / `pip` / `uv add` など Python 系コマンドを実行する予定

## Scripts

### 1) 初期作成（setup）

```bash
# macOS
bash scripts/setup-macos.sh [--python <version>] [--dry-run]

# Linux
bash scripts/setup-linux.sh [--python <version>] [--dry-run]
```

成果物:
- `assets/vX.Y.Z/.venv`
- `assets/vX.Y.Z/pyproject.toml`
- `assets/vX.Y.Z/uv.lock`
- `assets/vX.Y.Z/src/`

### 2) 切り替え（switch）

```bash
# source で実行すること（必須）
source scripts/switch-python.sh --python <version>
source scripts/switch-python.sh --dry-run --python <version>
```

`bash scripts/switch-python.sh ...` は current shell を変更しない。

### 3) 依存追加（add-deps）

```bash
# active venv を使う
bash scripts/add-deps.sh requests rich

# version 指定で実行
bash scripts/add-deps.sh --python 3.12 requests rich
```

### 4) 実行（推奨）

`run-python` を使わず、基本はそのまま `python` を実行する。

```bash
python /abs/path/to/script.py
python -m markitdown /abs/path/to/input.pptx
```

補助ランナー（互換用）:

```bash
bash scripts/run-python.sh --script /abs/path/to/script.py
bash scripts/run-python.sh --module markitdown -- /abs/path/to/input.pptx
bash scripts/run-python.sh --code "print('hello')" --name hello.py
```

### 5) 削除（remove）

```bash
bash scripts/remove-python.sh --python 3.12.10
bash scripts/remove-python.sh --dry-run --python 3.12.10
```

## Workflow

1. `setup-*` で env を作成
2. `source .../activate` で thread の実行環境を有効化

```bash
source /abs/path/to/skills/system/python-venv/assets/v3.12.10/.venv/bin/activate
# または
source scripts/switch-python.sh --python 3.12.10
```

3. 必要なら `add-deps.sh` で依存追加
4. 生成コードは `.py` に保存して `python <file.py>` で実行

## Rules

- Python env の path は `<skill-dir>/assets/vX.Y.Z/.venv` に統一する。
- version ごとに project/依存を分離する。
- setup/switch/add/remove/run 実行時に cwd を変更しない。
- 長文コードを MCP `args` に直接埋め込まない。まず `.py` として保存して実行する。
- `skill_run_script` の `path` は `scripts/<file>` のみを渡す。
- macOS/Linux の Bash フローは `assets/.env` 永続化や shim 配置に依存しない。
