---
name: workspace-venv
description: Cross-platform Python workspace bootstrap with uv. Use when setting up a new project directory, installing uv, creating a virtual environment with the latest available Python 3, activating the environment on Windows/macOS/Linux, and adding missing dependencies with uv add/lock/sync.
---

# Workspace Venv

`uv` でワークスペース単位の Python 仮想環境を作成し、依存関係を最小コマンドで管理する。

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

2. `uv` が使えるか確認する

```bash
uv --version
```

3. `uv` が使えない場合のみインストールする

```bash
# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

インストール後はシェルを再起動して `uv --version` を実行する。

4. `uv` で最新 Python 3 系の仮想環境を作成する

```bash
uv venv --python 3 .venv
```

5. 仮想環境を有効化する

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

6. 不足ライブラリを追加して同期する

```bash
uv add <package-name>
uv lock
uv sync
```

複数追加時は `uv add <pkg1> <pkg2>` を使う。

## Rules

- すべてのコマンドは `pyproject.toml` があるワークスペース直下で実行する。
- 依存追加は `pip install` ではなく `uv add` を優先する。
- 環境再現時は `uv sync` を実行してからアクティベートする。
