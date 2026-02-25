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

SCRIPT_SOURCE=""
if [[ -n "${BASH_SOURCE[0]-}" ]]; then
  SCRIPT_SOURCE="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION-}" ]]; then
  SCRIPT_SOURCE="$0"
else
  SCRIPT_SOURCE="$0"
fi

SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
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
        if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
      fi
      PYTHON_REQUEST="$2"
      shift 2
      ;;
    --workspace)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --workspace" >&2
        usage
        if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
      fi
      WORKSPACE_ARG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      if [[ "${IS_SOURCED}" -eq 1 ]]; then return 0; else exit 0; fi
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
      ;;
  esac
done

if [[ -z "${PYTHON_REQUEST}" ]]; then
  echo "--python <version> is required." >&2
  usage
  if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
fi

if [[ "${IS_SOURCED}" -ne 1 && "${DRY_RUN}" -ne 1 ]]; then
  echo "Run this script with source to apply deactivate/activate in current shell." >&2
  echo "Example: source scripts/switch-python.sh --python ${PYTHON_REQUEST}" >&2
  if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
fi

if ! WORKSPACE_DIR="$(detect_workspace_dir "${WORKSPACE_ARG}")"; then
  if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
fi
echo "Workspace directory: ${WORKSPACE_DIR}"

if ! ensure_uv; then
  if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
fi
if ! resolve_python_spec; then
  if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
fi

PYTHON_VERSION_TAG="v${PYTHON_VERSION}"
VENV_DIR="${SKILL_DIR}/assets/${PYTHON_VERSION_TAG}/.venv"
echo "Python request: ${PYTHON_REQUEST}"
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Venv path: ${VENV_DIR}"

if ! run_cmd mkdir -p "${WORKSPACE_DIR}"; then
  echo "Failed to prepare workspace directory: ${WORKSPACE_DIR}" >&2
  if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
fi
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ [ -f ${WORKSPACE_DIR}/pyproject.toml ] || uv --directory ${WORKSPACE_DIR} init --python ${PYTHON_BIN}"
else
  if [[ ! -f "${WORKSPACE_DIR}/pyproject.toml" ]]; then
    if ! run_cmd uv --directory "${WORKSPACE_DIR}" init --python "${PYTHON_BIN}"; then
      echo "Failed to initialize workspace project: ${WORKSPACE_DIR}" >&2
      if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
    fi
  fi
fi

if ! run_cmd mkdir -p "$(dirname "${VENV_DIR}")"; then
  echo "Failed to prepare venv directory: $(dirname "${VENV_DIR}")" >&2
  if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
fi
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ [ -d ${VENV_DIR} ] || uv venv --python ${PYTHON_BIN} ${VENV_DIR}"
else
  if [[ ! -d "${VENV_DIR}" ]]; then
    if ! run_cmd uv venv --python "${PYTHON_BIN}" "${VENV_DIR}"; then
      echo "Failed to create venv: ${VENV_DIR}" >&2
      if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
    fi
  fi
fi
if ! run_cmd env -u VIRTUAL_ENV UV_PROJECT_ENVIRONMENT="${VENV_DIR}" uv --project "${WORKSPACE_DIR}" sync --python "${PYTHON_BIN}"; then
  echo "Failed to sync dependencies for Python ${PYTHON_VERSION_TAG} in ${WORKSPACE_DIR}." >&2
  if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ deactivate (if active)"
  echo "+ source ${VENV_DIR}/bin/activate"
  if [[ "${IS_SOURCED}" -eq 1 ]]; then return 0; else exit 0; fi
fi

if command -v deactivate >/dev/null 2>&1; then
  deactivate || true
fi
if ! source "${VENV_DIR}/bin/activate"; then
  echo "Failed to activate environment: ${VENV_DIR}" >&2
  if [[ "${IS_SOURCED}" -eq 1 ]]; then return 1; else exit 1; fi
fi
echo "Activated VIRTUAL_ENV: ${VIRTUAL_ENV}"
if [[ "${IS_SOURCED}" -eq 1 ]]; then return 0; else exit 0; fi
