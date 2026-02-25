#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run-python.sh [--dry-run] [--python <version>] (--script <absolute-or-relative-path.py> | --module <module.name> | --code-base64 <base64>) [--name <generated.py>] [-- <script-args...>]

Examples:
  run-python.sh --python 3.12 --script /absolute/path/to/task.py
  run-python.sh --script ./task.py -- --input data.json --verbose
  run-python.sh --python 3.12 --module markitdown -- input.pptx
  run-python.sh --python 3.12 --code-base64 cHJpbnQoIkhlbGxvIikK --name hello.py
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
}

resolve_script_path() {
  local path="$1"
  if [[ "${path}" == /* ]]; then
    RESOLVED_SCRIPT_PATH="${path}"
    return 0
  fi
  RESOLVED_SCRIPT_PATH="$(cd -P . && pwd)/${path}"
}

validate_module_name() {
  local name="$1"
  if [[ -z "${name}" ]]; then
    echo "--module requires a module name." >&2
    return 1
  fi
  if [[ ! "${name}" =~ ^[A-Za-z_][A-Za-z0-9_\.]*$ ]]; then
    echo "Invalid --module value: ${name}" >&2
    echo "Use a dotted Python module path (example: markitdown)." >&2
    return 1
  fi
}

validate_script_name() {
  local name="$1"
  if [[ -z "${name}" ]]; then
    echo "--name is required when using --code-base64." >&2
    return 1
  fi
  if [[ "${name}" == */* || "${name}" == *\\* || "${name}" == .* || "${name}" == *".."* ]]; then
    echo "Invalid --name: ${name}" >&2
    echo "Use a safe filename under src/ (example: generated.py)." >&2
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
SCRIPT_PATH=""
MODULE_NAME=""
CODE_BASE64=""
GENERATED_SCRIPT_NAME="generated.py"
SCRIPT_ARGS=()
MODE=""
MODE_COUNT=0

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
      MODE="script"
      MODE_COUNT=$((MODE_COUNT + 1))
      SCRIPT_PATH="$2"
      shift 2
      ;;
    --module)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --module" >&2
        usage
        exit 1
      fi
      MODE="module"
      MODE_COUNT=$((MODE_COUNT + 1))
      MODULE_NAME="$2"
      shift 2
      ;;
    --code-base64)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --code-base64" >&2
        usage
        exit 1
      fi
      MODE="code"
      MODE_COUNT=$((MODE_COUNT + 1))
      CODE_BASE64="$2"
      shift 2
      ;;
    --name)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --name" >&2
        usage
        exit 1
      fi
      GENERATED_SCRIPT_NAME="$2"
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

if [[ "${MODE_COUNT}" -eq 0 ]]; then
  echo "Exactly one execution mode is required: --script, --module, or --code-base64." >&2
  usage
  exit 1
fi

if [[ "${MODE_COUNT}" -gt 1 ]]; then
  echo "--script, --module, and --code-base64 are mutually exclusive." >&2
  usage
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is not available. Run setup-macos.sh or setup-linux.sh first." >&2
  exit 1
fi

validate_version_request "${PYTHON_REQUEST}" || exit 1
resolve_version_from_uv || exit 1

echo "Python request: ${PYTHON_REQUEST}"
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Project directory: ${PROJECT_DIR}"

case "${MODE}" in
  script)
    resolve_script_path "${SCRIPT_PATH}"
    if [[ "${RESOLVED_SCRIPT_PATH}" != *.py ]]; then
      echo "--script must point to a .py file: ${RESOLVED_SCRIPT_PATH}" >&2
      exit 1
    fi
    if [[ "${DRY_RUN}" -eq 0 ]] && [[ ! -f "${RESOLVED_SCRIPT_PATH}" ]]; then
      echo "Script file not found: ${RESOLVED_SCRIPT_PATH}" >&2
      exit 1
    fi

    echo "Execution mode: script"
    echo "Script path: ${RESOLVED_SCRIPT_PATH}"
    if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
      run_cmd uv --project "${PROJECT_DIR}" run python "${RESOLVED_SCRIPT_PATH}" "${SCRIPT_ARGS[@]}"
    else
      run_cmd uv --project "${PROJECT_DIR}" run python "${RESOLVED_SCRIPT_PATH}"
    fi
    ;;
  module)
    validate_module_name "${MODULE_NAME}" || exit 1

    echo "Execution mode: module"
    echo "Module: ${MODULE_NAME}"
    if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
      run_cmd uv --project "${PROJECT_DIR}" run python -m "${MODULE_NAME}" "${SCRIPT_ARGS[@]}"
    else
      run_cmd uv --project "${PROJECT_DIR}" run python -m "${MODULE_NAME}"
    fi
    ;;
  code)
    CODE_BASE64="$(printf '%s' "${CODE_BASE64}" | tr -d '\r\n\t ')"
    if [[ -z "${CODE_BASE64}" ]]; then
      echo "--code-base64 requires non-empty base64 content." >&2
      exit 1
    fi
    validate_script_name "${GENERATED_SCRIPT_NAME}" || exit 1
    run_cmd mkdir -p "${SRC_DIR}"
    GENERATED_SCRIPT_PATH="${SRC_DIR}/${GENERATED_SCRIPT_NAME}"

    echo "Execution mode: generated-code"
    echo "Generated script path: ${GENERATED_SCRIPT_PATH}"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "+ write script to ${GENERATED_SCRIPT_PATH} from base64"
    else
      decode_base64_to_file "${CODE_BASE64}" "${GENERATED_SCRIPT_PATH}" || {
        echo "Failed to decode --code-base64." >&2
        exit 1
      }
    fi

    if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
      run_cmd uv --project "${PROJECT_DIR}" run python "${GENERATED_SCRIPT_PATH}" "${SCRIPT_ARGS[@]}"
    else
      run_cmd uv --project "${PROJECT_DIR}" run python "${GENERATED_SCRIPT_PATH}"
    fi
    ;;
  *)
    echo "Internal error: unknown execution mode '${MODE}'." >&2
    exit 1
    ;;
esac

persist_env_file

echo "Done."
