#!/usr/bin/env bash

IS_SOURCED=0
if [[ -n "${ZSH_VERSION-}" ]]; then
  case "${ZSH_EVAL_CONTEXT-}" in
    *:file)
      IS_SOURCED=1
      ;;
  esac
elif [[ -n "${BASH_SOURCE[0]-}" ]]; then
  if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    IS_SOURCED=1
  fi
fi

usage() {
  cat <<'EOF'
Usage:
  source switch-python.sh [--python <version>]
  bash switch-python.sh [--python <version>]
  source switch-python.sh --python 3.12
  source switch-python.sh --python 3.12.10

Dry run (can run without source):
  switch-python.sh --dry-run --python 3.12
  switch-python.sh --dry-run
EOF
}

exit_with_code() {
  local code="$1"
  if [[ "${IS_SOURCED}" -eq 1 ]]; then
    return "${code}"
  fi
  exit "${code}"
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

SCRIPT_SOURCE=""
if [[ -n "${BASH_SOURCE[0]-}" ]]; then
  SCRIPT_SOURCE="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION-}" ]]; then
  SCRIPT_SOURCE="$0"
else
  SCRIPT_SOURCE="$0"
fi

resolve_script_dir() {
  local src="${SCRIPT_SOURCE}"
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
  ACTIVATE_SCRIPT="${VENV_DIR}/bin/activate"

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
  if [[ ! -f "${ACTIVATE_SCRIPT}" ]]; then
    echo "Activation script not found: ${ACTIVATE_SCRIPT}" >&2
    echo "Run setup-macos.sh or setup-linux.sh first." >&2
    return 1
  fi
}

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
PYTHON_VENV_LAST_ACTION=switch
EOF
}

DRY_RUN=0
PYTHON_REQUEST=""

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
        exit_with_code 1
      fi
      PYTHON_REQUEST="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit_with_code 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit_with_code 1
      ;;
  esac
done

mkdir -p "${ASSETS_BASE_DIR}" || {
  echo "Failed to prepare assets directory: ${ASSETS_BASE_DIR}" >&2
  exit_with_code 1
}
load_env_file
if [[ -n "${PYTHON_VENV_ASSETS_DIR:-}" && "${PYTHON_VENV_ASSETS_DIR}" != "${ASSETS_BASE_DIR}" ]]; then
  ASSETS_BASE_DIR="${PYTHON_VENV_ASSETS_DIR}"
  ENV_FILE="${ASSETS_BASE_DIR}/.env"
  mkdir -p "${ASSETS_BASE_DIR}" || {
    echo "Failed to prepare assets directory: ${ASSETS_BASE_DIR}" >&2
    exit_with_code 1
  }
  load_env_file
fi

if [[ -z "${PYTHON_REQUEST}" && -n "${PYTHON_VENV_ACTIVE_VERSION:-}" ]]; then
  PYTHON_REQUEST="${PYTHON_VENV_ACTIVE_VERSION#v}"
  echo "Using PYTHON_VENV_ACTIVE_VERSION from ${ENV_FILE}: ${PYTHON_REQUEST}"
fi

if [[ -z "${PYTHON_REQUEST}" ]]; then
  echo "--python <version> is required (or set PYTHON_VENV_ACTIVE_VERSION in ${ENV_FILE})." >&2
  usage
  exit_with_code 1
fi

NON_SOURCE_MODE=0
if [[ "${IS_SOURCED}" -ne 1 ]]; then
  NON_SOURCE_MODE=1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is not available. Run setup-macos.sh or setup-linux.sh first." >&2
  exit_with_code 1
fi

validate_version_request "${PYTHON_REQUEST}" || exit_with_code 1
resolve_version_from_uv || exit_with_code 1

echo "Python request: ${PYTHON_REQUEST}"
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Venv path: ${VENV_DIR}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ deactivate (if active)"
  echo "+ source ${ACTIVATE_SCRIPT}"
  echo "+ write ${ENV_FILE}"
  exit_with_code 0
fi

if [[ "${NON_SOURCE_MODE}" -eq 1 ]]; then
  persist_env_file
  echo "Saved active version to ${ENV_FILE}."
  echo "Note: non-sourced execution cannot modify current shell."
  echo "If you need immediate shell activation, run:"
  echo "  source scripts/switch-python.sh --python ${PYTHON_REQUEST}"
  exit_with_code 0
fi

if command -v deactivate >/dev/null 2>&1; then
  deactivate || true
fi
source "${ACTIVATE_SCRIPT}"
persist_env_file
echo "Activated VIRTUAL_ENV: ${VIRTUAL_ENV}"
exit_with_code 0
