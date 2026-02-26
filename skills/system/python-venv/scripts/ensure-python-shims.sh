#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ensure-python-shims.sh --assets-dir <path> [--env-file <path>] [--dry-run]

Purpose:
  Install python/python3 shims into ~/.local/bin so plain `python` and `python3`
  resolve to PYTHON_VENV_ACTIVE_PYTHON_BIN from the skill .env file.
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

write_python_shim() {
  local shim_path="$1"
  local env_file_path="$2"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    cat <<EOF
+ cat > ${shim_path} <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${env_file_path}"
ACTIVE_PYTHON=""

if [[ -f "\${ENV_FILE}" ]]; then
  while IFS= read -r line || [[ -n "\${line}" ]]; do
    line="\${line%\$'\\r'}"
    line="\${line#\$'\\ufeff'}"
    [[ -z "\${line}" || "\${line}" == \\#* ]] && continue
    if [[ "\${line}" == PYTHON_VENV_ACTIVE_PYTHON_BIN=* ]]; then
      ACTIVE_PYTHON="\${line#PYTHON_VENV_ACTIVE_PYTHON_BIN=}"
      break
    fi
  done < "\${ENV_FILE}"
fi

if [[ -z "\${ACTIVE_PYTHON}" ]]; then
  echo "PYTHON_VENV_ACTIVE_PYTHON_BIN is not set in \${ENV_FILE}" >&2
  exit 1
fi

if [[ ! -x "\${ACTIVE_PYTHON}" ]]; then
  echo "Active Python is not executable: \${ACTIVE_PYTHON}" >&2
  exit 1
fi

exec "\${ACTIVE_PYTHON}" "\$@"
SHIM
EOF
    echo "+ chmod +x ${shim_path}"
    return 0
  fi

  cat > "${shim_path}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${env_file_path}"
ACTIVE_PYTHON=""

if [[ -f "\${ENV_FILE}" ]]; then
  while IFS= read -r line || [[ -n "\${line}" ]]; do
    line="\${line%\$'\\r'}"
    line="\${line#\$'\\ufeff'}"
    [[ -z "\${line}" || "\${line}" == \\#* ]] && continue
    if [[ "\${line}" == PYTHON_VENV_ACTIVE_PYTHON_BIN=* ]]; then
      ACTIVE_PYTHON="\${line#PYTHON_VENV_ACTIVE_PYTHON_BIN=}"
      break
    fi
  done < "\${ENV_FILE}"
fi

if [[ -z "\${ACTIVE_PYTHON}" ]]; then
  echo "PYTHON_VENV_ACTIVE_PYTHON_BIN is not set in \${ENV_FILE}" >&2
  exit 1
fi

if [[ ! -x "\${ACTIVE_PYTHON}" ]]; then
  echo "Active Python is not executable: \${ACTIVE_PYTHON}" >&2
  exit 1
fi

exec "\${ACTIVE_PYTHON}" "\$@"
EOF
  chmod +x "${shim_path}"
}

install_link_if_safe() {
  local link_path="$1"
  local target_path="$2"

  if [[ ! -e "${link_path}" ]]; then
    run_cmd ln -s "${target_path}" "${link_path}"
    return 0
  fi

  if [[ -L "${link_path}" ]]; then
    local current_target
    current_target="$(readlink "${link_path}")"
    if [[ "${current_target}" == "${target_path}" ]]; then
      return 0
    fi
    if [[ "${current_target}" == */shims/python || "${current_target}" == */shims/python3 ]]; then
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "+ ln -sfn ${target_path} ${link_path}"
      else
        ln -sfn "${target_path}" "${link_path}"
      fi
      return 0
    fi
  fi

  echo "Skip shim install for ${link_path}; existing file is not managed by python-venv skill." >&2
}

install_links_in_dir() {
  local link_dir="$1"
  local python_link="${link_dir}/python"
  local python3_link="${link_dir}/python3"

  run_cmd mkdir -p "${link_dir}"
  install_link_if_safe "${python_link}" "${PYTHON_SHIM}"
  install_link_if_safe "${python3_link}" "${PYTHON3_SHIM}"
}

DRY_RUN=0
ASSETS_DIR=""
ENV_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --assets-dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --assets-dir" >&2
        usage
        exit 1
      fi
      ASSETS_DIR="$2"
      shift 2
      ;;
    --env-file)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --env-file" >&2
        usage
        exit 1
      fi
      ENV_FILE="$2"
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

if [[ -z "${ASSETS_DIR}" ]]; then
  echo "--assets-dir is required" >&2
  usage
  exit 1
fi

if [[ -z "${ENV_FILE}" ]]; then
  ENV_FILE="${ASSETS_DIR}/.env"
fi

SHIM_DIR="${ASSETS_DIR}/shims"
LOCAL_BIN="${HOME}/.local/bin"
PYTHON_SHIM="${SHIM_DIR}/python"
PYTHON3_SHIM="${SHIM_DIR}/python3"
ADDITIONAL_LINK_DIR=""

run_cmd mkdir -p "${SHIM_DIR}"
write_python_shim "${PYTHON_SHIM}" "${ENV_FILE}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "+ ln -sf ${PYTHON_SHIM} ${PYTHON3_SHIM}"
else
  ln -sf "${PYTHON_SHIM}" "${PYTHON3_SHIM}"
fi

install_links_in_dir "${LOCAL_BIN}"

UV_BIN="$(command -v uv 2>/dev/null || true)"
if [[ -n "${UV_BIN}" ]]; then
  UV_BIN_DIR="$(cd -P "$(dirname "${UV_BIN}")" && pwd)"
  if [[ "${UV_BIN_DIR}" != "${LOCAL_BIN}" ]]; then
    if [[ -w "${UV_BIN_DIR}" || "${DRY_RUN}" -eq 1 ]]; then
      install_links_in_dir "${UV_BIN_DIR}"
      ADDITIONAL_LINK_DIR="${UV_BIN_DIR}"
    else
      echo "Skip shim install for ${UV_BIN_DIR}; directory is not writable." >&2
    fi
  fi
fi

PATH_HAS_LOCAL_BIN=0
case ":${PATH}:" in
  *:"${LOCAL_BIN}":*)
    PATH_HAS_LOCAL_BIN=1
    ;;
esac
if [[ "${PATH_HAS_LOCAL_BIN}" -eq 0 ]]; then
  echo "Warning: ${LOCAL_BIN} is not on PATH." >&2
  echo "Add it to PATH to use plain 'python' command with this skill env." >&2
fi

echo "Python shims ready:"
echo "  ${LOCAL_BIN}/python -> ${PYTHON_SHIM}"
echo "  ${LOCAL_BIN}/python3 -> ${PYTHON3_SHIM}"
if [[ -n "${ADDITIONAL_LINK_DIR}" ]]; then
  echo "  ${ADDITIONAL_LINK_DIR}/python -> ${PYTHON_SHIM}"
  echo "  ${ADDITIONAL_LINK_DIR}/python3 -> ${PYTHON3_SHIM}"
fi
