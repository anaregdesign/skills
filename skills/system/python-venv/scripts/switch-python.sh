#!/usr/bin/env bash

IS_SOURCED=0
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  IS_SOURCED=1
fi

finish() {
  local code="${1:-0}"
  if [[ "${IS_SOURCED}" -eq 1 ]]; then
    return "${code}"
  fi
  exit "${code}"
}

usage() {
  cat <<'EOF'
Usage:
  source switch-python.sh --python <version> [--workspace <dir>]
  source switch-python.sh --python 3.12.10
  source switch-python.sh --python 3.13 --workspace ~/work/my-app

Dry run (can run without source):
  switch-python.sh --dry-run --python 3.12.10 --workspace ~/work/my-app
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

expand_home_path() {
  local path="$1"
  case "${path}" in
    "~")
      printf '%s\n' "${HOME}"
      ;;
    "~/"*)
      printf '%s/%s\n' "${HOME}" "${path#~/}"
      ;;
    *)
      printf '%s\n' "${path}"
      ;;
  esac
}

detect_workspace_dir() {
  local explicit_dir="${1:-}"
  local detected_dir=""
  local git_root=""

  if [[ -n "${explicit_dir}" ]]; then
    detected_dir="${explicit_dir}"
  elif [[ -f "${PWD}/pyproject.toml" ]]; then
    detected_dir="${PWD}"
  else
    if command -v git >/dev/null 2>&1; then
      git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    fi
    if [[ -n "${git_root}" && -f "${git_root}/pyproject.toml" ]]; then
      detected_dir="${git_root}"
    elif [[ -n "${git_root}" ]]; then
      detected_dir="${git_root}"
    elif [[ -n "${PWD}" ]]; then
      detected_dir="${PWD}"
    fi
  fi

  if [[ -z "${detected_dir}" ]]; then
    if [[ -t 0 ]]; then
      read -r -p "Workspace directory was not auto-detected. Enter path: " detected_dir
    else
      echo "Workspace directory was not auto-detected. Pass --workspace <dir>." >&2
      return 1
    fi
  fi

  detected_dir="$(expand_home_path "${detected_dir}")"
  if [[ -z "${detected_dir}" ]]; then
    echo "Workspace directory is empty." >&2
    return 1
  fi

  if [[ "${detected_dir}" != /* ]]; then
    detected_dir="${PWD}/${detected_dir}"
  fi

  printf '%s\n' "${detected_dir}"
}

ensure_uv() {
  if command -v uv >/dev/null 2>&1; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "+ uv --version"
    else
      uv --version
    fi
    return 0
  fi

  echo "uv not found. Installing uv..."
  run_cmd sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  if [[ -x "${HOME}/.local/bin/uv" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  fi

  if [[ "${DRY_RUN}" -eq 0 ]] && ! command -v uv >/dev/null 2>&1; then
    echo "uv install finished but uv is still not on PATH. Restart your shell and rerun." >&2
    return 1
  fi
}

resolve_python_spec() {
  local python_json=""
  local resolved_version=""
  local resolved_python_bin=""

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "+ uv python install ${PYTHON_REQUEST} --managed-python"
  else
    run_cmd uv python install "${PYTHON_REQUEST}" --managed-python
  fi

  if command -v uv >/dev/null 2>&1; then
    python_json="$(
      uv python list "${PYTHON_REQUEST}" --managed-python --only-installed --output-format json 2>/dev/null || true
    )"
    resolved_version="$(printf '%s\n' "${python_json}" | grep -o '"version":"[0-9.]*"' | head -n1 | cut -d'"' -f4 || true)"
    resolved_python_bin="$(printf '%s\n' "${python_json}" | grep -o '"path":"[^"]*"' | head -n1 | cut -d'"' -f4 || true)"
  fi

  if [[ -z "${resolved_version}" ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      resolved_version="x.x.x"
    else
      echo "Could not resolve managed Python version for '${PYTHON_REQUEST}'." >&2
      return 1
    fi
  fi

  if [[ -z "${resolved_python_bin}" ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      resolved_python_bin="python3"
    else
      echo "Could not resolve managed Python executable path." >&2
      return 1
    fi
  fi

  PYTHON_VERSION="${resolved_version}"
  PYTHON_BIN="${resolved_python_bin}"
}

DRY_RUN=0
WORKSPACE_ARG=""
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
        finish 1
      fi
      PYTHON_REQUEST="$2"
      shift 2
      ;;
    --workspace)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --workspace" >&2
        usage
        finish 1
      fi
      WORKSPACE_ARG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      finish 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      finish 1
      ;;
  esac
done

if [[ -z "${PYTHON_REQUEST}" ]]; then
  echo "--python <version> is required." >&2
  usage
  finish 1
fi

if [[ "${IS_SOURCED}" -ne 1 && "${DRY_RUN}" -ne 1 ]]; then
  echo "Run this script with source to apply deactivate/activate in current shell." >&2
  echo "Example: source scripts/switch-python.sh --python ${PYTHON_REQUEST}" >&2
  finish 1
fi

WORKSPACE_DIR="$(detect_workspace_dir "${WORKSPACE_ARG}")" || finish 1
echo "Workspace directory: ${WORKSPACE_DIR}"

ensure_uv || finish 1
resolve_python_spec || finish 1

PYTHON_VERSION_TAG="v${PYTHON_VERSION}"
VENV_DIR="${SKILL_DIR}/venv/${PYTHON_VERSION_TAG}/.venv"
echo "Python request: ${PYTHON_REQUEST}"
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Venv path: ${VENV_DIR}"

run_cmd mkdir -p "${WORKSPACE_DIR}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ [ -f ${WORKSPACE_DIR}/pyproject.toml ] || uv --directory ${WORKSPACE_DIR} init"
else
  if [[ ! -f "${WORKSPACE_DIR}/pyproject.toml" ]]; then
    run_cmd uv --directory "${WORKSPACE_DIR}" init
  fi
fi

run_cmd mkdir -p "$(dirname "${VENV_DIR}")"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ [ -d ${VENV_DIR} ] || uv venv --python ${PYTHON_BIN} ${VENV_DIR}"
else
  if [[ ! -d "${VENV_DIR}" ]]; then
    run_cmd uv venv --python "${PYTHON_BIN}" "${VENV_DIR}"
  fi
fi
run_cmd env UV_PROJECT_ENVIRONMENT="${VENV_DIR}" uv --project "${WORKSPACE_DIR}" sync

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ deactivate (if active)"
  echo "+ source ${VENV_DIR}/bin/activate"
  finish 0
fi

if declare -F deactivate >/dev/null 2>&1; then
  deactivate || true
fi
source "${VENV_DIR}/bin/activate"
echo "Activated VIRTUAL_ENV: ${VIRTUAL_ENV}"

finish 0
