#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  run-python.sh [--dry-run] [--python <version>] (--script <path.py> | --module <module.name> | --code <python-code> | --code-base64 <base64> | --code-chunk <part>) [--name <generated.py>] [-- <args...>]

Examples:
  run-python.sh --script /abs/path/to/task.py
  run-python.sh --module markitdown -- /abs/path/to/input.pptx
  run-python.sh --code "print('hello')" --name hello.py
  run-python.sh --python 3.12 --script ./task.py -- --input data.json
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

validate_version_request() {
  local req="${1#v}"
  if [[ ! "${req}" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "Invalid --python value: $1" >&2
    echo "Use one of: 3 / 3.12 / 3.12.10" >&2
    return 1
  fi
  NORMALIZED_REQUEST="${req}"
}

resolve_project_from_request() {
  local python_json=""
  local resolved_version=""
  local dir=""
  local base=""
  local version=""
  local matches=()

  if command -v uv >/dev/null 2>&1; then
    python_json="$(uv python list "${NORMALIZED_REQUEST}" --managed-python --only-installed --output-format json 2>/dev/null || true)"
    resolved_version="$(printf '%s\n' "${python_json}" | grep -o '"version":"[0-9.]*"' | head -n1 | cut -d'"' -f4 || true)"
  fi

  if [[ -z "${resolved_version}" ]]; then
    for dir in "${ASSETS_BASE_DIR}"/v*; do
      [[ -d "${dir}" ]] || continue
      base="${dir##*/}"
      [[ "${base}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
      version="${base#v}"

      case "${NORMALIZED_REQUEST}" in
        *.*.*)
          [[ "${version}" == "${NORMALIZED_REQUEST}" ]] || continue
          ;;
        *.*)
          [[ "${version}" == "${NORMALIZED_REQUEST}".* ]] || continue
          ;;
        *)
          [[ "${version}" == "${NORMALIZED_REQUEST}".* ]] || continue
          ;;
      esac
      matches+=("${version}")
    done

    if [[ ${#matches[@]} -gt 0 ]]; then
      resolved_version="$(printf '%s\n' "${matches[@]}" | sort -V | tail -n1)"
    fi
  fi

  if [[ -z "${resolved_version}" ]]; then
    echo "No Python env found for request: ${NORMALIZED_REQUEST}" >&2
    echo "Run setup-macos.sh or setup-linux.sh first." >&2
    return 1
  fi

  PYTHON_VERSION_TAG="v${resolved_version}"
  PROJECT_DIR="${ASSETS_BASE_DIR}/${PYTHON_VERSION_TAG}"
  VENV_DIR="${PROJECT_DIR}/.venv"
  PYTHON_BIN="${VENV_DIR}/bin/python"

  if [[ ! -x "${PYTHON_BIN}" || ! -f "${PROJECT_DIR}/pyproject.toml" ]]; then
    echo "Project is not ready: ${PROJECT_DIR}" >&2
    echo "Run setup-macos.sh or setup-linux.sh first." >&2
    return 1
  fi
}

resolve_project_from_active_venv() {
  local active_venv="${VIRTUAL_ENV:-}"
  if [[ -z "${active_venv}" ]]; then
    return 1
  fi
  active_venv="${active_venv%/}"
  local project_dir
  project_dir="$(cd -P "${active_venv}/.." && pwd)"
  local python_bin="${active_venv}/bin/python"

  if [[ ! -x "${python_bin}" ]]; then
    return 1
  fi

  PROJECT_DIR="${project_dir}"
  VENV_DIR="${active_venv}"
  PYTHON_BIN="${python_bin}"
  PYTHON_VERSION_TAG="${project_dir##*/}"
}

resolve_script_path() {
  local path="$1"
  if [[ "${path}" == /* ]]; then
    RESOLVED_SCRIPT_PATH="${path}"
  else
    RESOLVED_SCRIPT_PATH="$(cd -P . && pwd)/${path}"
  fi
}

validate_module_name() {
  local name="$1"
  if [[ ! "${name}" =~ ^[A-Za-z_][A-Za-z0-9_\.]*$ ]]; then
    echo "Invalid --module value: ${name}" >&2
    return 1
  fi
}

validate_script_name() {
  local name="$1"
  if [[ -z "${name}" ]]; then
    echo "--name is required when using code modes." >&2
    return 1
  fi
  if [[ "${name}" == */* || "${name}" == *\\* || "${name}" == .* || "${name}" == *".."* ]]; then
    echo "Invalid --name: ${name}" >&2
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

join_code_chunks() {
  local joined=""
  local chunk
  for chunk in "${CODE_CHUNKS[@]}"; do
    joined+="${chunk}"
  done
  CODE_TEXT_FROM_CHUNKS="${joined}"
}

DRY_RUN=0
PYTHON_REQUEST=""
SCRIPT_PATH=""
MODULE_NAME=""
CODE_TEXT=""
CODE_BASE64=""
CODE_CHUNKS=()
CODE_TEXT_FROM_CHUNKS=""
GENERATED_SCRIPT_NAME="generated.py"
SCRIPT_ARGS=()
MODE=""
MODE_COUNT=0

set_mode() {
  local requested="$1"
  if [[ -z "${MODE}" ]]; then
    MODE="${requested}"
    MODE_COUNT=1
    return 0
  fi
  if [[ "${MODE}" == "${requested}" ]]; then
    return 0
  fi
  MODE_COUNT=$((MODE_COUNT + 1))
}

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
      set_mode "script"
      SCRIPT_PATH="$2"
      shift 2
      ;;
    --module)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --module" >&2
        usage
        exit 1
      fi
      set_mode "module"
      MODULE_NAME="$2"
      shift 2
      ;;
    -c|--code)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for $1" >&2
        usage
        exit 1
      fi
      set_mode "code-text"
      CODE_TEXT="$2"
      shift 2
      ;;
    --code-base64)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --code-base64" >&2
        usage
        exit 1
      fi
      set_mode "code-base64"
      CODE_BASE64="$2"
      shift 2
      ;;
    --code-chunk)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --code-chunk" >&2
        usage
        exit 1
      fi
      set_mode "code-chunks"
      CODE_CHUNKS+=("$2")
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
      if [[ -z "${MODE}" && "$1" == *.py ]]; then
        set_mode "script"
        SCRIPT_PATH="$1"
        shift
        SCRIPT_ARGS=("$@")
        break
      fi
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "${MODE_COUNT}" -eq 0 ]]; then
  echo "Exactly one execution mode is required." >&2
  usage
  exit 1
fi
if [[ "${MODE_COUNT}" -gt 1 ]]; then
  echo "--script, --module, --code, --code-base64, --code-chunk are mutually exclusive." >&2
  usage
  exit 1
fi

SCRIPT_DIR="$(resolve_script_dir)"
SKILL_DIR="$(cd -P "${SCRIPT_DIR}/.." && pwd)"
ASSETS_BASE_DIR="${PYTHON_VENV_ASSETS_DIR:-${SKILL_DIR}/assets}"

if [[ -n "${PYTHON_REQUEST}" ]]; then
  validate_version_request "${PYTHON_REQUEST}" || exit 1
  resolve_project_from_request || exit 1
else
  if ! resolve_project_from_active_venv; then
    echo "No active virtualenv. Source '.venv/bin/activate' first or pass --python." >&2
    exit 1
  fi
fi

echo "Python binary: ${PYTHON_BIN}"
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
    if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
      run_cmd "${PYTHON_BIN}" "${RESOLVED_SCRIPT_PATH}" "${SCRIPT_ARGS[@]}"
    else
      run_cmd "${PYTHON_BIN}" "${RESOLVED_SCRIPT_PATH}"
    fi
    ;;
  module)
    validate_module_name "${MODULE_NAME}" || exit 1
    if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
      run_cmd "${PYTHON_BIN}" -m "${MODULE_NAME}" "${SCRIPT_ARGS[@]}"
    else
      run_cmd "${PYTHON_BIN}" -m "${MODULE_NAME}"
    fi
    ;;
  code-base64)
    CODE_BASE64="$(printf '%s' "${CODE_BASE64}" | tr -d '\r\n\t ')"
    [[ -n "${CODE_BASE64}" ]] || { echo "--code-base64 requires non-empty content." >&2; exit 1; }
    validate_script_name "${GENERATED_SCRIPT_NAME}" || exit 1
    SRC_DIR="${PROJECT_DIR}/src"
    run_cmd mkdir -p "${SRC_DIR}"
    GENERATED_SCRIPT_PATH="${SRC_DIR}/${GENERATED_SCRIPT_NAME}"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "+ write ${GENERATED_SCRIPT_PATH} from base64"
    else
      decode_base64_to_file "${CODE_BASE64}" "${GENERATED_SCRIPT_PATH}"
    fi
    if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
      run_cmd "${PYTHON_BIN}" "${GENERATED_SCRIPT_PATH}" "${SCRIPT_ARGS[@]}"
    else
      run_cmd "${PYTHON_BIN}" "${GENERATED_SCRIPT_PATH}"
    fi
    ;;
  code-text)
    [[ -n "${CODE_TEXT}" ]] || { echo "--code requires non-empty code." >&2; exit 1; }
    validate_script_name "${GENERATED_SCRIPT_NAME}" || exit 1
    SRC_DIR="${PROJECT_DIR}/src"
    run_cmd mkdir -p "${SRC_DIR}"
    GENERATED_SCRIPT_PATH="${SRC_DIR}/${GENERATED_SCRIPT_NAME}"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "+ write ${GENERATED_SCRIPT_PATH} from --code"
    else
      printf '%s\n' "${CODE_TEXT}" > "${GENERATED_SCRIPT_PATH}"
    fi
    if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
      run_cmd "${PYTHON_BIN}" "${GENERATED_SCRIPT_PATH}" "${SCRIPT_ARGS[@]}"
    else
      run_cmd "${PYTHON_BIN}" "${GENERATED_SCRIPT_PATH}"
    fi
    ;;
  code-chunks)
    [[ ${#CODE_CHUNKS[@]} -gt 0 ]] || { echo "--code-chunk requires at least one chunk." >&2; exit 1; }
    join_code_chunks
    [[ -n "${CODE_TEXT_FROM_CHUNKS}" ]] || { echo "--code-chunk content is empty." >&2; exit 1; }
    validate_script_name "${GENERATED_SCRIPT_NAME}" || exit 1
    SRC_DIR="${PROJECT_DIR}/src"
    run_cmd mkdir -p "${SRC_DIR}"
    GENERATED_SCRIPT_PATH="${SRC_DIR}/${GENERATED_SCRIPT_NAME}"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "+ write ${GENERATED_SCRIPT_PATH} from --code-chunk"
    else
      printf '%s\n' "${CODE_TEXT_FROM_CHUNKS}" > "${GENERATED_SCRIPT_PATH}"
    fi
    if [[ ${#SCRIPT_ARGS[@]} -gt 0 ]]; then
      run_cmd "${PYTHON_BIN}" "${GENERATED_SCRIPT_PATH}" "${SCRIPT_ARGS[@]}"
    else
      run_cmd "${PYTHON_BIN}" "${GENERATED_SCRIPT_PATH}"
    fi
    ;;
  *)
    echo "Internal error: unknown mode '${MODE}'." >&2
    exit 1
    ;;
esac

echo "Done."
