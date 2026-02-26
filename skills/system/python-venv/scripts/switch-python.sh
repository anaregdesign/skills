#!/usr/bin/env bash
set -euo pipefail

IS_SOURCED=0
if [[ -n "${ZSH_VERSION-}" ]]; then
  case "${ZSH_EVAL_CONTEXT-}" in
    *:file) IS_SOURCED=1 ;;
  esac
elif [[ -n "${BASH_SOURCE[0]-}" ]] && [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  IS_SOURCED=1
fi

usage() {
  cat <<'USAGE'
Usage:
  source switch-python.sh --python <version>
  source switch-python.sh --dry-run --python <version>
  bash switch-python.sh --python <version>

Examples:
  source switch-python.sh --python 3.12
  source switch-python.sh --python 3.12.10
USAGE
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

resolve_version_from_assets_or_uv() {
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
  ACTIVATE_SCRIPT="${VENV_DIR}/bin/activate"

  if [[ ! -f "${ACTIVATE_SCRIPT}" ]]; then
    echo "Activation script not found: ${ACTIVATE_SCRIPT}" >&2
    echo "Run setup-macos.sh or setup-linux.sh first." >&2
    return 1
  fi
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
    *)
      echo "Unknown option: $1" >&2
      usage
      exit_with_code 1
      ;;
  esac
done

if [[ -z "${PYTHON_REQUEST}" ]]; then
  echo "--python <version> is required." >&2
  usage
  exit_with_code 1
fi

SCRIPT_DIR="$(resolve_script_dir)"
SKILL_DIR="$(cd -P "${SCRIPT_DIR}/.." && pwd)"
ASSETS_BASE_DIR="${PYTHON_VENV_ASSETS_DIR:-${SKILL_DIR}/assets}"

validate_version_request "${PYTHON_REQUEST}" || exit_with_code 1
resolve_version_from_assets_or_uv || exit_with_code 1

echo "Python request: ${PYTHON_REQUEST}"
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Venv path: ${VENV_DIR}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ source ${ACTIVATE_SCRIPT}"
  exit_with_code 0
fi

if [[ "${IS_SOURCED}" -ne 1 ]]; then
  echo "This command must be sourced to affect current shell." >&2
  echo "Run: source ${ACTIVATE_SCRIPT}" >&2
  exit_with_code 1
fi

if command -v deactivate >/dev/null 2>&1; then
  deactivate || true
fi
source "${ACTIVATE_SCRIPT}"
echo "Activated VIRTUAL_ENV: ${VIRTUAL_ENV}"
