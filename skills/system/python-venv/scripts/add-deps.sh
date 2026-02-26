#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  add-deps.sh [--dry-run] [--python <version>] <package...>

Examples:
  add-deps.sh --python 3.12 requests
  add-deps.sh --python 3.12.10 requests rich pydantic
  add-deps.sh --dry-run --python 3 fastapi uvicorn
  add-deps.sh requests rich
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
  local version_from_assets=""

  resolve_version_from_assets() {
    local dir=""
    local base=""
    local version=""
    local matches=()

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

    if [[ ${#matches[@]} -eq 0 ]]; then
      return 1
    fi

    printf '%s\n' "${matches[@]}" | sort -V | tail -n1
  }

  python_json="$(
    uv python list "${NORMALIZED_REQUEST}" --managed-python --only-installed --output-format json 2>/dev/null || true
  )"
  resolved_version="$(printf '%s\n' "${python_json}" | grep -o '"version":"[0-9.]*"' | head -n1 | cut -d'"' -f4 || true)"

  if [[ -z "${resolved_version}" ]]; then
    version_from_assets="$(resolve_version_from_assets || true)"
    if [[ -n "${version_from_assets}" ]]; then
      resolved_version="${version_from_assets}"
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
PYTHON_VENV_ACTIVE_PYTHON_BIN=${PYTHON_BIN}
PYTHON_VENV_LAST_ACTION=add-deps
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
if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

PACKAGES=("$@")

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is not available. Run setup-macos.sh or setup-linux.sh first." >&2
  exit 1
fi

validate_version_request "${PYTHON_REQUEST}" || exit 1
resolve_version_from_uv || exit 1

echo "Python request: ${PYTHON_REQUEST}"
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Venv path: ${VENV_DIR}"
echo "Project directory: ${PROJECT_DIR}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ uv --version"
else
  uv --version
fi

run_cmd uv --project "${PROJECT_DIR}" add --python "${PYTHON_BIN}" "${PACKAGES[@]}"
run_cmd uv --project "${PROJECT_DIR}" lock --python "${PYTHON_BIN}"
run_cmd uv --project "${PROJECT_DIR}" sync --python "${PYTHON_BIN}"
persist_env_file

echo "Done."
