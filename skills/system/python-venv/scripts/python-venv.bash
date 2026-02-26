# shellcheck shell=bash

python_venv__usage() {
  cat <<'EOF'
Usage:
  python_venv ensure <X.Y.Z>
  python_venv activate <X.Y.Z>
  python_venv deactivate
  python_venv use <X.Y.Z>
  python_venv add <X.Y.Z> <dep...>
  python_venv path <X.Y.Z>
EOF
}

python_venv__skill_dir() {
  local script_path script_dir
  script_path="${BASH_SOURCE[0]}"
  script_dir="$(cd "$(dirname "$script_path")" && pwd)"
  printf '%s\n' "$(cd "$script_dir/.." && pwd)"
}

python_venv__env_dir() {
  local version="$1"
  printf '%s/assets/v%s\n' "$(python_venv__skill_dir)" "$version"
}

python_venv__require_uv() {
  if ! command -v uv >/dev/null 2>&1; then
    echo "uv command not found in PATH." >&2
    return 1
  fi
}

python_venv__ensure() {
  local version="$1"
  local env_dir

  if [[ -z "$version" ]]; then
    echo "Usage: python_venv ensure <X.Y.Z>" >&2
    return 1
  fi

  python_venv__require_uv || return 1
  env_dir="$(python_venv__env_dir "$version")"
  mkdir -p "$env_dir" || return 1

  if [[ ! -f "$env_dir/pyproject.toml" ]]; then
    (
      cd "$env_dir" &&
        uv init --bare --python "$version" --name "python_v${version//./_}"
    ) || return 1
  fi

  (
    cd "$env_dir" &&
      uv venv --python "$version"
  ) || return 1
}

python_venv__activate() {
  local version="$1"
  local env_dir
  local activate_path

  if [[ -z "$version" ]]; then
    echo "Usage: python_venv activate <X.Y.Z>" >&2
    return 1
  fi

  env_dir="$(python_venv__env_dir "$version")"
  activate_path="$env_dir/.venv/bin/activate"

  if [[ ! -f "$activate_path" ]]; then
    python_venv__ensure "$version" || return 1
  fi

  # shellcheck source=/dev/null
  source "$activate_path"
}

python_venv__deactivate() {
  if [[ -z "${VIRTUAL_ENV:-}" ]]; then
    return 0
  fi

  if type deactivate >/dev/null 2>&1; then
    deactivate
    return $?
  fi

  echo "A virtual environment is active, but deactivate function is unavailable." >&2
  return 1
}

python_venv__add() {
  local version="$1"
  local env_dir

  shift
  if [[ -z "$version" || "$#" -eq 0 ]]; then
    echo "Usage: python_venv add <X.Y.Z> <dep...>" >&2
    return 1
  fi

  python_venv__ensure "$version" || return 1
  env_dir="$(python_venv__env_dir "$version")"

  (
    cd "$env_dir" &&
      uv add "$@" &&
      uv lock &&
      uv sync
  ) || return 1
}

python_venv() {
  local action="${1:-}"
  local version
  local target_venv

  case "$action" in
    ensure)
      version="${2:-}"
      [[ -n "$version" ]] || {
        python_venv__usage >&2
        return 1
      }
      python_venv__ensure "$version"
      ;;
    activate)
      version="${2:-}"
      [[ -n "$version" ]] || {
        python_venv__usage >&2
        return 1
      }
      target_venv="$(python_venv__env_dir "$version")/.venv"
      if [[ -n "${VIRTUAL_ENV:-}" && "${VIRTUAL_ENV}" != "$target_venv" ]]; then
        python_venv__deactivate || return 1
      fi
      python_venv__activate "$version"
      ;;
    deactivate)
      python_venv__deactivate
      ;;
    use)
      version="${2:-}"
      [[ -n "$version" ]] || {
        python_venv__usage >&2
        return 1
      }
      python_venv__ensure "$version" || return 1
      target_venv="$(python_venv__env_dir "$version")/.venv"
      if [[ -n "${VIRTUAL_ENV:-}" && "${VIRTUAL_ENV}" != "$target_venv" ]]; then
        python_venv__deactivate || return 1
      fi
      python_venv__activate "$version"
      ;;
    add)
      version="${2:-}"
      [[ -n "$version" && "$#" -ge 3 ]] || {
        python_venv__usage >&2
        return 1
      }
      shift 2
      python_venv__add "$version" "$@"
      ;;
    path)
      version="${2:-}"
      [[ -n "$version" ]] || {
        python_venv__usage >&2
        return 1
      }
      python_venv__env_dir "$version"
      ;;
    *)
      python_venv__usage >&2
      return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Source this file instead of executing it: source scripts/python-venv.bash" >&2
  exit 1
fi
