#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  setup-linux.sh [--dry-run] [--python <version>]

Examples:
  setup-linux.sh
  setup-linux.sh --python 3.12
  setup-linux.sh --python 3.12.10
  setup-linux.sh --dry-run
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

ensure_src_runner_scripts() {
  local src_dir="${PYTHON_VERSION_DIR}/src"
  local shell_template="${SCRIPT_DIR}/src-runner.sh"
  local pwsh_template="${SCRIPT_DIR}/src-runner.ps1"
  local shell_runner="${src_dir}/run-generated.sh"
  local pwsh_runner="${src_dir}/run-generated.ps1"

  if [[ ! -f "${shell_template}" ]]; then
    echo "Runner template not found: ${shell_template}" >&2
    return 1
  fi
  if [[ ! -f "${pwsh_template}" ]]; then
    echo "Runner template not found: ${pwsh_template}" >&2
    return 1
  fi

  run_cmd mkdir -p "${src_dir}"
  run_cmd cp "${shell_template}" "${shell_runner}"
  run_cmd chmod +x "${shell_runner}"
  run_cmd cp "${pwsh_template}" "${pwsh_runner}"
}

DRY_RUN=0
PYTHON_REQUEST="3"
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

if [[ $# -gt 0 ]]; then
  echo "Too many arguments." >&2
  usage
  exit 1
fi

ASSETS_BASE_DIR="${SKILL_DIR}/assets"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  printf '+ mkdir -p %q\n' "${ASSETS_BASE_DIR}"
  printf '+ cd %q\n' "${ASSETS_BASE_DIR}"
else
  mkdir -p "${ASSETS_BASE_DIR}"
  cd "${ASSETS_BASE_DIR}"
fi

if command -v uv >/dev/null 2>&1; then
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    uv --version
  else
    echo "+ uv --version"
  fi
else
  echo "uv not found. Installing uv for Linux..."
  run_cmd sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  if [[ -x "${HOME}/.local/bin/uv" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
  if [[ "${DRY_RUN}" -eq 0 ]] && ! command -v uv >/dev/null 2>&1; then
    echo "uv install finished but uv is still not on PATH. Restart your shell and rerun." >&2
    exit 1
  fi
fi

resolve_python_spec || exit 1
PYTHON_VERSION_TAG="v${PYTHON_VERSION}"
PYTHON_VERSION_DIR="${ASSETS_BASE_DIR}/${PYTHON_VERSION_TAG}"
VENV_DIR="${PYTHON_VERSION_DIR}/.venv"
PROJECT_DIR="${PYTHON_VERSION_DIR}"
echo "Python request: ${PYTHON_REQUEST}"
echo "Python version: ${PYTHON_VERSION_TAG}"
echo "Venv path: ${VENV_DIR}"

run_cmd mkdir -p "${PYTHON_VERSION_DIR}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ [ -f ${PROJECT_DIR}/pyproject.toml ] || uv --directory ${PROJECT_DIR} init --bare --python ${PYTHON_BIN}"
else
  if [[ ! -f "${PROJECT_DIR}/pyproject.toml" ]]; then
    run_cmd uv --directory "${PROJECT_DIR}" init --bare --python "${PYTHON_BIN}"
  fi
fi
echo "Project directory: ${PROJECT_DIR}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  printf '+ cd %q\n' "${PYTHON_VERSION_DIR}"
else
  cd "${PYTHON_VERSION_DIR}"
fi
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ [ -d ${VENV_DIR} ] || uv venv --python ${PYTHON_BIN} ${VENV_DIR}"
else
  if [[ -d "${VENV_DIR}" ]]; then
    echo "Venv already exists. Skip create: ${VENV_DIR}"
  else
    run_cmd uv venv --python "${PYTHON_BIN}" "${VENV_DIR}"
  fi
fi
run_cmd env -u VIRTUAL_ENV UV_PROJECT_ENVIRONMENT="${VENV_DIR}" uv --project "${PROJECT_DIR}" sync --python "${PYTHON_BIN}"
ensure_src_runner_scripts || exit 1

echo "Done."
echo "Activate with: source ${VENV_DIR}/bin/activate"
echo "Generated script runner (bash): ${PYTHON_VERSION_DIR}/src/run-generated.sh"
echo "Generated script runner (PowerShell): ${PYTHON_VERSION_DIR}/src/run-generated.ps1"
