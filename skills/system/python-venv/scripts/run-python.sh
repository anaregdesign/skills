#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run-python.sh [--dry-run] [--python <version>] --script <absolute-or-relative-path.py> [-- <script-args...>]

Examples:
  run-python.sh --python 3.12 --script /absolute/path/to/task.py
  run-python.sh --script ./task.py -- --input data.json --verbose
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

SCRIPT_DIR="$(resolve_script_dir)"
DEFAULT_SKILL_DIR="$(cd -P "${SCRIPT_DIR}/.." && pwd)"
SKILL_DIR="${PYTHON_VENV_SKILL_DIR:-${DEFAULT_SKILL_DIR}}"
ASSETS_BASE_DIR="${PYTHON_VENV_ASSETS_DIR:-${SKILL_DIR}/assets}"
ENV_FILE="${ASSETS_BASE_DIR}/.env"

load_env_file() {
  if [[ -f "${ENV_FILE}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
      line="${line%$'\r'}"
      line="${line#$'\ufeff'}"
      [[ -z "${line}" || "${line}" == \#* ]] && continue
      if [[ "${line}" == *=* ]]; then
        local key="${line%%=*}"
        local value="${line#*=}"
        if [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
          printf -v "${key}" '%s' "${value}"
          export "${key}"
        fi
      fi
    done < "${ENV_FILE}"
  fi
}

persist_env_file() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "+ write ${ENV_FILE}"
    return 0
  fi

  cat > "${ENV_FILE}" <<EOF
PYTHON_VENV_SKILL_DIR=${SKILL_DIR}
PYTHON_VENV_ASSETS_DIR=${ASSETS_BASE_DIR}
PYTHON_VENV_ACTIVE_VERSION=${PYTHON_VERSION_TAG}
PYTHON_VENV_ACTIVE_PROJECT_DIR=${PROJECT_DIR}
PYTHON_VENV_ACTIVE_VENV_DIR=${VENV_DIR}
PYTHON_VENV_ACTIVE_PYTHON_BIN=${VENV_DIR}/bin/python
PYTHON_VENV_LAST_ACTION=run-python
EOF
}

validate_version_request() {
  local req="${1#v}"
  if [[ ! "${req}" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "Invalid --python value: $1" >&2
    echo "Use one of: 3 / 3.12 / 3.12.10" >&2
    return 1
  fi
  NORMALIZED_REQUEST="${req}"
}

resolve_version_from_uv() {
  local python_json=""
  local resolved_version=""

  python_json="$(
    uv python list "${NORMALIZED_REQUEST}" --managed-python --only-installed --output-format json 2>/dev/null || true
  )"
  resolved_version="$(printf '%s\n' "${python_json}" | grep -o '"version":"[0-9.]*"' | head -n1 | cut -d'"' -f4 || true)"

  if [[ -z "${resolved_version}" ]]; then
    echo "No uv-managed Python found for request: ${NORMALIZED_REQUEST}" >&2
    echo "Run setup-macos.sh or setup-linux.sh first." >&2
    return 1
  fi

  PYTHON_VERSION_TAG="v${resolved_version}"
  PROJECT_DIR="${ASSETS_BASE_DIR}/${PYTHON_VERSION_TAG}"
  VENV_DIR="${PROJECT_DIR}/.venv"

  if [[ ! -d "${PROJECT_DIR}" ]]; then
    echo "Project directory not found: ${PROJECT_DIR}" >&2
    echo "Run setup-macos.sh or setup-linux.sh first." >&2
    return 1
  fi
  if [[ ! -d "${VENV_DIR}" ]]; then
    echo "Expected venv does not exist: ${VENV_DIR}" >&2
    echo "Run setup-macos.sh or setup-linux.sh first." >&2
    return 1
  fi
  if [[ ! -f "${PROJECT_DIR}/pyproject.toml" ]]; then
    echo "Project metadata not found: ${PROJECT_DIR}/pyproject.toml" >&2
    echo "Run setup-macos.sh or setup-linux.sh first." >&2
    return 1
  fi
}

resolve_script_path() {
  local path="$1"
  if [[ "${path}" == /* ]]; then
    RESOLVED_SCRIPT_PATH="${path}"
    return 0
  fi
  RESOLVED_SCRIPT_PATH="$(cd -P . && pwd)/${path}"
}

DRY_RUN=0
PYTHON_REQUEST=""
SCRIPT_PATH=""
SCRIPT_ARGS=()

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
    --script)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --script" >&2
        usage
        exit 1
      fi
      SCRIPT_PATH="$2"
      shift 2
      ;;
    --)
      shift
      SCRIPT_ARGS=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

run_cmd mkdir -p "${ASSETS_BASE_DIR}"
load_env_file
if [[ -n "${PYTHON_VENV_ASSETS_DIR:-}" && "${PYTHON_VENV_ASSETS_DIR}" != "${ASSETS_BASE_DIR}" ]]; then
  ASSETS_BASE_DIR="${PYTHON_VENV_ASSETS_DIR}"
  ENV_FILE="${ASSETS_BASE_DIR}/.env"
  run_cmd mkdir -p "${ASSETS_BASE_DIR}"
  load_env_file
fi

if [[ -z "${PYTHON_REQUEST}" && -n "${PYTHON_VENV_ACTIVE_VERSION:-}" ]]; then
  PYTHON_REQUEST="${PYTHON_VENV_ACTIVE_VERSION#v}"
  echo "Using PYTHON_VENV_ACTIVE_VERSION from ${ENV_FILE}: ${PYTHON_REQUEST}"
fi

if [[ -z "${PYTHON_REQUEST}" ]]; then
  echo "--python <version> is required (or set PYTHON_VENV_ACTIVE_VERSION in ${ENV_FILE})." >&2
  usage
  exit 1
fi

if [[ -z "${SCRIPT_PATH}" ]]; then
  echo "--script <path.py> is required." >&2
  usage
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is not available. Run setup-macos.sh or setup-linux.sh first." >&2
  exit 1
fi

validate_version_request "${PYTHON_REQUEST}" || exit 1
resolve_version_from_uv || exit 1
resolve_script_path "${SCRIPT_PATH}"

if [[ "${RESOLVED_SCRIPT_PATH}" != *.py ]]; then
  echo "--script must point to a .py file: ${RESOLVED_SCRIPT_PATH}" >&2
  exit 1
fi

if [[ "${DRY_RUN}" -eq 0 ]] && [[ ! -f "${RESOLVED_SCRIPT_PATH}" ]]; then
  echo "Script file not found: ${RESOLVED_SCRIPT_PATH}" >&2
  exit 1
fi

echo "Python request: ${PYTHON_REQUEST}"
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Project directory: ${PROJECT_DIR}"
echo "Script path: ${RESOLVED_SCRIPT_PATH}"

if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
  run_cmd uv --project "${PROJECT_DIR}" run python "${RESOLVED_SCRIPT_PATH}" "${SCRIPT_ARGS[@]}"
else
  run_cmd uv --project "${PROJECT_DIR}" run python "${RESOLVED_SCRIPT_PATH}"
fi
persist_env_file

echo "Done."
