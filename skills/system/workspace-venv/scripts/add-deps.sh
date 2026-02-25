#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  add-deps.sh [--dry-run] <workspace-dir> <package...>

Examples:
  add-deps.sh ~/work/my-app requests
  add-deps.sh ~/work/my-app requests rich pydantic
  add-deps.sh --dry-run ~/work/my-app fastapi uvicorn
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

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

WORKSPACE_DIR="$1"
shift
PACKAGES=("$@")

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is not available. Run setup-macos.sh or setup-linux.sh first." >&2
  exit 1
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ uv --version"
  printf '+ cd %q\n' "${WORKSPACE_DIR}"
else
  uv --version
  cd "${WORKSPACE_DIR}"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ test -f pyproject.toml"
else
  if [[ ! -f pyproject.toml ]]; then
    echo "pyproject.toml not found in ${WORKSPACE_DIR}" >&2
    exit 1
  fi
fi

run_cmd uv add "${PACKAGES[@]}"
run_cmd uv lock
run_cmd uv sync

echo "Done."
