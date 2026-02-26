#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  remove-python.sh [--dry-run] --python <x.y.z>
  remove-python.sh [--dry-run]

Examples:
  remove-python.sh --python 3.12.10
  remove-python.sh --dry-run --python 3.12.10
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

version_from_active_venv() {
  local active_venv="${VIRTUAL_ENV:-}"
  if [[ -z "${active_venv}" ]]; then
    return 1
  fi
  active_venv="${active_venv%/}"
  if [[ "${active_venv}" != "${ASSETS_BASE_DIR}"/v*/.venv ]]; then
    return 1
  fi
  printf '%s' "${active_venv#${ASSETS_BASE_DIR}/}"
  printf '\n'
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
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(resolve_script_dir)"
SKILL_DIR="$(cd -P "${SCRIPT_DIR}/.." && pwd)"
ASSETS_BASE_DIR="${PYTHON_VENV_ASSETS_DIR:-${SKILL_DIR}/assets}"

if [[ -z "${PYTHON_REQUEST}" ]]; then
  ACTIVE_TAG="$(version_from_active_venv || true)"
  if [[ -n "${ACTIVE_TAG}" ]]; then
    PYTHON_VERSION_TAG="${ACTIVE_TAG}"
  else
    echo "--python <x.y.z> is required (or activate target env first)." >&2
    usage
    exit 1
  fi
else
  PYTHON_VERSION_TAG="$(normalize_version_tag "${PYTHON_REQUEST}")" || exit 1
fi

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

run_cmd rm -rf "${TARGET_DIR}"

echo "Done. Removed ${TARGET_DIR}"
