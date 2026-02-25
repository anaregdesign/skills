#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  setup-macos.sh [--dry-run] [workspace-dir]

Examples:
  setup-macos.sh
  setup-macos.sh ~/work/my-app
  setup-macos.sh --dry-run
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
      echo "Workspace directory was not auto-detected. Pass [workspace-dir]." >&2
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

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
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

if [[ $# -gt 1 ]]; then
  echo "Too many arguments." >&2
  usage
  exit 1
fi

WORKSPACE_ARG=""
if [[ $# -eq 1 ]]; then
  WORKSPACE_ARG="$1"
fi

WORKSPACE_DIR="$(detect_workspace_dir "${WORKSPACE_ARG}")" || exit 1
echo "Workspace directory: ${WORKSPACE_DIR}"

if command -v uv >/dev/null 2>&1; then
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    uv --version
  else
    echo "+ uv --version"
  fi
else
  echo "uv not found. Installing uv for macOS..."
  run_cmd sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  if [[ -x "${HOME}/.local/bin/uv" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
  if [[ "${DRY_RUN}" -eq 0 ]] && ! command -v uv >/dev/null 2>&1; then
    echo "uv install finished but uv is still not on PATH. Restart your shell and rerun." >&2
    exit 1
  fi
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  printf '+ mkdir -p %q\n' "${WORKSPACE_DIR}"
  printf '+ cd %q\n' "${WORKSPACE_DIR}"
  echo "+ [ -f pyproject.toml ] || uv init"
else
  mkdir -p "${WORKSPACE_DIR}"
  cd "${WORKSPACE_DIR}"
  if [[ ! -f pyproject.toml ]]; then
    run_cmd uv init
  fi
fi

run_cmd uv venv --python 3 .venv

run_cmd uv sync

echo "Done."
echo "Activate with: source ${WORKSPACE_DIR}/.venv/bin/activate"
