#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./run-generated.sh <script.py> [args...]

Examples:
  ./run-generated.sh hello.py
  ./run-generated.sh tools/batch_job.py --limit 50
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${RUNNER_DIR}/.." && pwd)"
VENV_DIR="${PROJECT_DIR}/.venv"
PYTHON_BIN="${VENV_DIR}/bin/python"

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "Project venv not found: ${VENV_DIR}" >&2
  echo "Run setup/switch script for this Python version first." >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is not available. Run setup script first." >&2
  exit 1
fi

TARGET_SCRIPT="$1"
shift

if [[ "${TARGET_SCRIPT}" = /* ]]; then
  SCRIPT_PATH="${TARGET_SCRIPT}"
else
  SCRIPT_PATH="${RUNNER_DIR}/${TARGET_SCRIPT}"
fi

if [[ ! -f "${SCRIPT_PATH}" ]]; then
  echo "Script not found: ${SCRIPT_PATH}" >&2
  exit 1
fi

env -u VIRTUAL_ENV UV_PROJECT_ENVIRONMENT="${VENV_DIR}" \
  uv --project "${PROJECT_DIR}" run --python "${PYTHON_BIN}" python "${SCRIPT_PATH}" "$@"
