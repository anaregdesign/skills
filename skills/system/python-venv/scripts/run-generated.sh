#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run-generated.sh [--dry-run] [--python <version>] --name <file.py> --code-base64 <base64>

Examples:
  run-generated.sh --python 3.12 --name hello.py --code-base64 cHJpbnQoIkhlbGxvIikK
  run-generated.sh --name hello.py --code-base64 cHJpbnQoIkhlbGxvIikK
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
PYTHON_VENV_LAST_ACTION=run-generated
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
  SRC_DIR="${PROJECT_DIR}/src"

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
  run_cmd mkdir -p "${SRC_DIR}"
}

validate_script_name() {
  local name="$1"
  if [[ -z "${name}" ]]; then
    echo "--name is required." >&2
    return 1
  fi
  if [[ "${name}" == */* || "${name}" == *\\* || "${name}" == .* || "${name}" == *".."* ]]; then
    echo "Invalid --name: ${name}" >&2
    echo "Use a safe filename under src/ (example: hello.py)." >&2
    return 1
  fi
  if [[ "${name}" != *.py ]]; then
    echo "--name must end with .py: ${name}" >&2
    return 1
  fi
}

decode_base64_to_file() {
  local encoded="$1"
  local output_path="$2"
  if base64 --help 2>&1 | grep -q -- '--decode'; then
    printf '%s' "${encoded}" | base64 --decode > "${output_path}"
  else
    printf '%s' "${encoded}" | base64 -D > "${output_path}"
  fi
}

DRY_RUN=0
PYTHON_REQUEST=""
SCRIPT_NAME=""
CODE_BASE64=""
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
    --name)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --name" >&2
        usage
        exit 1
      fi
      SCRIPT_NAME="$2"
      shift 2
      ;;
    --code-base64)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --code-base64" >&2
        usage
        exit 1
      fi
      CODE_BASE64="$2"
      shift 2
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

if [[ -z "${SCRIPT_NAME}" || -z "${CODE_BASE64}" ]]; then
  echo "--name and --code-base64 are required." >&2
  usage
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is not available. Run setup-macos.sh or setup-linux.sh first." >&2
  exit 1
fi

validate_script_name "${SCRIPT_NAME}" || exit 1
CODE_BASE64="$(printf '%s' "${CODE_BASE64}" | tr -d '\r\n\t ')"
validate_version_request "${PYTHON_REQUEST}" || exit 1
resolve_version_from_uv || exit 1

SCRIPT_PATH="${SRC_DIR}/${SCRIPT_NAME}"
echo "Python request: ${PYTHON_REQUEST}"
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Project directory: ${PROJECT_DIR}"
echo "Script path: ${SCRIPT_PATH}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ write script to ${SCRIPT_PATH} from base64"
else
  decode_base64_to_file "${CODE_BASE64}" "${SCRIPT_PATH}"
fi
run_cmd uv --project "${PROJECT_DIR}" run python "${SCRIPT_PATH}"
persist_env_file

