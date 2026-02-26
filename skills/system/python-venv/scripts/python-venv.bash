# shellcheck shell=bash

python_venv__usage() {
  cat <<'EOF'
Usage:
  python_venv ensure <X.Y.Z>
  python_venv activate <X.Y.Z>
  python_venv deactivate
  python_venv use <X.Y.Z>
  python_venv <X.Y.Z>        # compatibility: same as "use <X.Y.Z>"
  python_venv add <X.Y.Z> <dep...>
  python_venv path <X.Y.Z>
EOF
}

python_venv__skill_dir() {
  local script_path script_dir current_dir
  script_path="${BASH_SOURCE[0]}"
  script_dir="$(cd "$(dirname "$script_path")" && pwd)"
  current_dir="$script_dir"

  while true; do
    if [[ -f "$current_dir/SKILL.md" ]]; then
      printf '%s\n' "$current_dir"
      return 0
    fi

    if [[ "$current_dir" == "/" ]]; then
      break
    fi
    current_dir="$(dirname "$current_dir")"
  done

  echo "SKILL.md not found while resolving skill directory from: $script_path" >&2
  return 1
}

python_venv__env_dir() {
  local version="$1"
  local skill_dir
  skill_dir="$(python_venv__skill_dir)" || return 1
  printf '%s/assets/v%s\n' "$skill_dir" "$version"
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
  env_dir="$(python_venv__env_dir "$version")" || return 1
  mkdir -p "$env_dir" || return 1

  if [[ ! -f "$env_dir/pyproject.toml" ]]; then
    (
      cd "$env_dir" &&
        uv init --bare --python "$version" --name "python_v${version//./_}"
    ) || return 1
  fi

  (
    cd "$env_dir" &&
      uv venv --python "$version" --allow-existing
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

  env_dir="$(python_venv__env_dir "$version")" || return 1
  activate_path="$env_dir/.venv/bin/activate"

  if [[ ! -f "$activate_path" ]]; then
    python_venv__ensure "$version" || return 1
  fi

  # shellcheck source=/dev/null
  source "$activate_path"
}

python_venv__deactivate() {
  local old_virtual_env
  local clean_path=""
  local entry
  local -a _python_venv_path_entries=()

  if [[ -z "${VIRTUAL_ENV:-}" ]]; then
    return 0
  fi

  if type deactivate >/dev/null 2>&1; then
    deactivate
    return $?
  fi

  old_virtual_env="$VIRTUAL_ENV"
  unset VIRTUAL_ENV
  unset VIRTUAL_ENV_PROMPT

  IFS=':' read -r -a _python_venv_path_entries <<< "${PATH:-}"
  for entry in "${_python_venv_path_entries[@]}"; do
    if [[ -z "$entry" || "$entry" == "$old_virtual_env/bin" || "$entry" == "$old_virtual_env/Scripts" ]]; then
      continue
    fi
    if [[ -z "$clean_path" ]]; then
      clean_path="$entry"
    else
      clean_path="${clean_path}:$entry"
    fi
  done
  export PATH="$clean_path"
  return 0
}

python_venv__is_non_python_dep() {
  local dep="$1"
  case "$dep" in
    pptxgenjs | npm:pptxgenjs)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

python_venv__add() {
  local version="$1"
  local env_dir
  local dep
  local -a python_deps=()
  local -a skipped_deps=()

  shift
  if [[ -z "$version" || "$#" -eq 0 ]]; then
    echo "Usage: python_venv add <X.Y.Z> <dep...>" >&2
    return 1
  fi

  python_venv__ensure "$version" || return 1
  env_dir="$(python_venv__env_dir "$version")" || return 1

  for dep in "$@"; do
    if python_venv__is_non_python_dep "$dep"; then
      skipped_deps+=("$dep")
    else
      python_deps+=("$dep")
    fi
  done

  if [[ "${#skipped_deps[@]}" -gt 0 ]]; then
    echo "Skipping non-Python dependencies: ${skipped_deps[*]}. Install with: npm install -g pptxgenjs" >&2
  fi

  if [[ "${#python_deps[@]}" -eq 0 ]]; then
    return 0
  fi

  (
    cd "$env_dir" &&
      uv add "${python_deps[@]}" &&
      uv lock &&
      uv sync
  ) || return 1
}

python_venv() {
  local action="${1:-}"
  local action_arg2="${2:-}"
  local version
  local target_venv

  # Backward compatibility: accept a bare version as "use <version>".
  if [[ "$action" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && -z "$action_arg2" ]]; then
    action_arg2="$action"
    action="use"
  fi

  case "$action" in
    ensure)
      version="$action_arg2"
      [[ -n "$version" ]] || {
        python_venv__usage >&2
        return 1
      }
      python_venv__ensure "$version"
      ;;
    activate)
      version="$action_arg2"
      [[ -n "$version" ]] || {
        python_venv__usage >&2
        return 1
      }
      target_venv="$(python_venv__env_dir "$version")" || return 1
      target_venv="${target_venv}/.venv"
      if [[ -n "${VIRTUAL_ENV:-}" && "${VIRTUAL_ENV}" != "$target_venv" ]]; then
        python_venv__deactivate || return 1
      fi
      python_venv__activate "$version"
      ;;
    deactivate)
      python_venv__deactivate
      ;;
    use)
      version="$action_arg2"
      [[ -n "$version" ]] || {
        python_venv__usage >&2
        return 1
      }
      python_venv__ensure "$version" || return 1
      target_venv="$(python_venv__env_dir "$version")" || return 1
      target_venv="${target_venv}/.venv"
      if [[ -n "${VIRTUAL_ENV:-}" && "${VIRTUAL_ENV}" != "$target_venv" ]]; then
        python_venv__deactivate || return 1
      fi
      python_venv__activate "$version"
      ;;
    add)
      version="$action_arg2"
      [[ -n "$version" && "$#" -ge 3 ]] || {
        python_venv__usage >&2
        return 1
      }
      shift 2
      python_venv__add "$version" "$@"
      ;;
    path)
      version="$action_arg2"
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
  python_venv "$@"
  exit $?
fi
