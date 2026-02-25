#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  add-deps.sh [--dry-run] <workspace-dir> <package...>

Examples:
  add-deps.sh ~/work/my-app requests
  add-deps.sh ~/work/my-app requests rich pydantic
  add-deps.sh --dry-run ~/work/my-app fastapi uvicorn
EOF
}

run_cmd() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '+'
    for arg in "$@"; do
      printf ' %q' "${arg}"
    done
    printf '\n'
    return 0
  fi
  "$@"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

resolve_existing_venv_dir() {
  local venv_base="${SKILL_DIR}/venv"
  local latest_version=""
  local active_venv="${VIRTUAL_ENV:-}"

  if [[ -n "${active_venv}" ]]; then
    active_venv="${active_venv%/}"
    case "${active_venv}" in
      "${SKILL_DIR}/venv/"v*"/.venv")
        if [[ -d "${active_venv}" ]]; then
          VENV_DIR="${active_venv}"
          PYTHON_VERSION_TAG="$(basename "$(dirname "${VENV_DIR}")")"
          return 0
        fi
        ;;
    esac
  fi

  if [[ -d "${venv_base}" ]]; then
    latest_version="$(
      find "${venv_base}" -mindepth 1 -maxdepth 1 -type d -name 'v*' -exec basename {} \; 2>/dev/null \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
        | sed 's/^v//' \
        | sort -V \
        | tail -n1
    )"
  fi

  if [[ -z "${latest_version}" ]]; then
    echo "No venv found under ${venv_base}. Run setup-macos.sh or setup-linux.sh first." >&2
    return 1
  fi

  PYTHON_VERSION_TAG="v${latest_version}"
  VENV_DIR="${venv_base}/${PYTHON_VERSION_TAG}/.venv"
  if [[ ! -d "${VENV_DIR}" ]]; then
    echo "Expected venv does not exist: ${VENV_DIR}" >&2
    return 1
  fi
}

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

WORKSPACE_DIR="$1"
shift
PACKAGES=("$@")

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is not available. Run setup-macos.sh or setup-linux.sh first." >&2
  exit 1
fi

resolve_existing_venv_dir || exit 1
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Venv path: ${VENV_DIR}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ uv --version"
  printf '+ cd %q\n' "${WORKSPACE_DIR}"
else
  uv --version
  cd "${WORKSPACE_DIR}"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ test -f pyproject.toml"
else
  if [[ ! -f pyproject.toml ]]; then
    echo "pyproject.toml not found in ${WORKSPACE_DIR}" >&2
    exit 1
  fi
fi

run_cmd uv add "${PACKAGES[@]}"
run_cmd uv lock
run_cmd env UV_PROJECT_ENVIRONMENT="${VENV_DIR}" uv sync

echo "Done."
