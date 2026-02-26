#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  setup-macos.sh [--dry-run] [--python <version>]

Examples:
  setup-macos.sh
  setup-macos.sh --python 3.12
  setup-macos.sh --python 3.12.10
  setup-macos.sh --dry-run
USAGE
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

resolve_script_dir() {
  local src="${BASH_SOURCE[0]}"
  while [[ -h "${src}" ]]; do
    local dir
    dir="$(cd -P "$(dirname "${src}")" && pwd)"
    src="$(readlink "${src}")"
    if [[ "${src}" != /* ]]; then
      src="${dir}/${src}"
    fi
  done
  cd -P "$(dirname "${src}")" && pwd
}

ensure_uv() {
  if command -v uv >/dev/null 2>&1; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "+ uv --version"
    else
      uv --version
    fi
    return 0
  fi

  echo "uv not found. Installing uv for macOS..."
  run_cmd sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  if [[ -x "${HOME}/.local/bin/uv" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
  if [[ "${DRY_RUN}" -eq 0 ]] && ! command -v uv >/dev/null 2>&1; then
    echo "uv install finished but uv is still not on PATH. Restart your shell and rerun." >&2
    exit 1
  fi
}

resolve_python_spec() {
  local python_json=""
  local resolved_version=""
  local resolved_python_bin=""

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "+ uv python install ${PYTHON_REQUEST} --managed-python"
    PYTHON_VERSION="x.x.x"
    PYTHON_BIN="python3"
    return 0
  fi

  run_cmd uv python install "${PYTHON_REQUEST}" --managed-python

  python_json="$(uv python list "${PYTHON_REQUEST}" --managed-python --only-installed --output-format json 2>/dev/null || true)"
  resolved_version="$(printf '%s\n' "${python_json}" | grep -o '"version":"[0-9.]*"' | head -n1 | cut -d'"' -f4 || true)"
  resolved_python_bin="$(printf '%s\n' "${python_json}" | grep -o '"path":"[^"]*"' | head -n1 | cut -d'"' -f4 || true)"

  if [[ -z "${resolved_version}" || -z "${resolved_python_bin}" ]]; then
    echo "Could not resolve managed Python for '${PYTHON_REQUEST}'." >&2
    exit 1
  fi

  PYTHON_VERSION="${resolved_version}"
  PYTHON_BIN="${resolved_python_bin}"
}

DRY_RUN=0
PYTHON_REQUEST="3"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --python|--python-version)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for $1" >&2
        usage
        exit 1
      fi
      PYTHON_REQUEST="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  echo "Too many arguments." >&2
  usage
  exit 1
fi

SCRIPT_DIR="$(resolve_script_dir)"
SKILL_DIR="$(cd -P "${SCRIPT_DIR}/.." && pwd)"
ASSETS_BASE_DIR="${PYTHON_VENV_ASSETS_DIR:-${SKILL_DIR}/assets}"

run_cmd mkdir -p "${ASSETS_BASE_DIR}"
ensure_uv
resolve_python_spec

PYTHON_VERSION_TAG="v${PYTHON_VERSION}"
PROJECT_DIR="${ASSETS_BASE_DIR}/${PYTHON_VERSION_TAG}"
VENV_DIR="${PROJECT_DIR}/.venv"
ACTIVATE_SCRIPT="${VENV_DIR}/bin/activate"

echo "Python request: ${PYTHON_REQUEST}"
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Project directory: ${PROJECT_DIR}"
echo "Venv path: ${VENV_DIR}"

run_cmd mkdir -p "${PROJECT_DIR}" "${PROJECT_DIR}/src"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ [ -f ${PROJECT_DIR}/pyproject.toml ] || uv --directory ${PROJECT_DIR} init --bare --python ${PYTHON_BIN}"
else
  if [[ ! -f "${PROJECT_DIR}/pyproject.toml" ]]; then
    run_cmd uv --directory "${PROJECT_DIR}" init --bare --python "${PYTHON_BIN}"
  fi
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ [ -d ${VENV_DIR} ] || uv venv --python ${PYTHON_BIN} ${VENV_DIR}"
else
  if [[ ! -d "${VENV_DIR}" ]]; then
    run_cmd uv venv --python "${PYTHON_BIN}" "${VENV_DIR}"
  fi
fi

run_cmd uv --project "${PROJECT_DIR}" sync --python "${PYTHON_BIN}"

echo "Done."
echo "Activate in this thread with:"
echo "  source ${ACTIVATE_SCRIPT}"
