#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  setup-macos.sh [--dry-run] <workspace-dir>

Examples:
  setup-macos.sh ~/work/my-app
  setup-macos.sh --dry-run ~/work/my-app
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

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

WORKSPACE_DIR="$1"

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
