#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  add-deps.sh [--dry-run] [--python <version>] <package...>

Examples:
  add-deps.sh requests rich
  add-deps.sh --python 3.12 requests
  add-deps.sh --dry-run --python 3.12 fastapi uvicorn
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

  if [[ ! -x "${python_bin}" || ! -f "${project_dir}/pyproject.toml" ]]; then
    return 1
  fi

  PROJECT_DIR="${project_dir}"
  VENV_DIR="${active_venv}"
  PYTHON_BIN="${python_bin}"
  PYTHON_VERSION_TAG="${project_dir##*/}"
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
    -* )
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

PACKAGES=("$@")

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is not available. Run setup-macos.sh or setup-linux.sh first." >&2
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

echo "Project directory: ${PROJECT_DIR}"
echo "Venv path: ${VENV_DIR}"

run_cmd uv --project "${PROJECT_DIR}" add --python "${PYTHON_BIN}" "${PACKAGES[@]}"
run_cmd uv --project "${PROJECT_DIR}" lock --python "${PYTHON_BIN}"
run_cmd uv --project "${PROJECT_DIR}" sync --python "${PYTHON_BIN}"

echo "Done."
