#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  remove-python.sh [--dry-run] [--python <version>]

Examples:
  remove-python.sh --python 3.12.10
  remove-python.sh --python v3.12.10
  remove-python.sh --dry-run --python 3.12.10
  remove-python.sh
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

normalize_version_tag() {
  local raw="$1"
  local ver="${raw#v}"
  if [[ ! "${ver}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid --python value: ${raw}" >&2
    echo "Use exact version like 3.12.10." >&2
    return 1
  fi
  printf 'v%s' "${ver}"
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

clear_active_env_file() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "+ write ${ENV_FILE}"
    return 0
  fi

  cat > "${ENV_FILE}" <<EOF
PYTHON_VENV_SKILL_DIR=${SKILL_DIR}
PYTHON_VENV_ASSETS_DIR=${ASSETS_BASE_DIR}
PYTHON_VENV_LAST_ACTION=remove
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

load_env_file
if [[ -n "${PYTHON_VENV_ASSETS_DIR:-}" && "${PYTHON_VENV_ASSETS_DIR}" != "${ASSETS_BASE_DIR}" ]]; then
  ASSETS_BASE_DIR="${PYTHON_VENV_ASSETS_DIR}"
  ENV_FILE="${ASSETS_BASE_DIR}/.env"
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

if [[ $# -gt 0 ]]; then
  echo "Too many arguments." >&2
  usage
  exit 1
fi

PYTHON_VERSION_TAG="$(normalize_version_tag "${PYTHON_REQUEST}")" || exit 1
TARGET_DIR="${ASSETS_BASE_DIR}/${PYTHON_VERSION_TAG}"
TARGET_VENV="${TARGET_DIR}/.venv"

echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Target path: ${TARGET_DIR}"

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Nothing to remove. Directory not found: ${TARGET_DIR}"
  exit 0
fi

ACTIVE_VENV="${VIRTUAL_ENV:-}"
if [[ -n "${ACTIVE_VENV}" ]]; then
  ACTIVE_VENV="${ACTIVE_VENV%/}"
  if [[ "${ACTIVE_VENV}" == "${TARGET_VENV}" ]]; then
    echo "Target environment is currently active: ${ACTIVE_VENV}" >&2
    echo "Deactivate it first, then run remove-python.sh again." >&2
    exit 1
  fi
fi

if [[ -z "${ACTIVE_VENV}" && "${PYTHON_VENV_ACTIVE_VENV_DIR:-}" == "${TARGET_VENV}" ]]; then
  echo "Note: ${ENV_FILE} indicates this version was last active in another process."
fi

run_cmd rm -rf "${TARGET_DIR}"

if [[ "${PYTHON_VENV_ACTIVE_VERSION:-}" == "${PYTHON_VERSION_TAG}" ]]; then
  clear_active_env_file
fi

echo "Done. Removed ${TARGET_DIR}"
