set -g PYTHON_VENV_FISH_SCRIPT_PATH (status filename)

function __python_venv_usage
    printf "Usage:\n"
    printf "  python_venv ensure <X.Y.Z>\n"
    printf "  python_venv activate <X.Y.Z>\n"
    printf "  python_venv deactivate\n"
    printf "  python_venv use <X.Y.Z>\n"
    printf "  python_venv add <X.Y.Z> <dep...>\n"
    printf "  python_venv path <X.Y.Z>\n"
end

function __python_venv_skill_dir
    set -l script_dir (dirname "$PYTHON_VENV_FISH_SCRIPT_PATH")
    set -l previous_dir (pwd)

    cd "$script_dir"; or return 1
    set -l current_dir (pwd)
    cd "$previous_dir"; or return 1

    while true
        if test -f "$current_dir/SKILL.md"
            printf "%s\n" "$current_dir"
            return 0
        end

        if test "$current_dir" = "/"
            break
        end

        set -l parent_dir (dirname "$current_dir")
        if test -z "$parent_dir"; or test "$parent_dir" = "$current_dir"
            break
        end
        set current_dir "$parent_dir"
    end

    echo "SKILL.md not found while resolving skill directory from: $PYTHON_VENV_FISH_SCRIPT_PATH" >&2
    return 1
end

function __python_venv_env_dir --argument-names version
    set -l skill_dir (__python_venv_skill_dir); or return 1
    printf "%s/assets/v%s\n" "$skill_dir" "$version"
end

function __python_venv_require_uv
    if not type -q uv
        echo "uv command not found in PATH." >&2
        return 1
    end
end

function __python_venv_ensure --argument-names version
    if test -z "$version"
        echo "Usage: python_venv ensure <X.Y.Z>" >&2
        return 1
    end

    __python_venv_require_uv; or return 1
    set -l env_dir (__python_venv_env_dir "$version"); or return 1
    mkdir -p "$env_dir"; or return 1

    if not test -f "$env_dir/pyproject.toml"
        set -l previous_dir (pwd)
        cd "$env_dir"; or return 1
        uv init --bare --python "$version" --name "python_v"(string replace -a "." "_" "$version")
        set -l status_code $status
        cd "$previous_dir"; or return 1
        test $status_code -eq 0; or return $status_code
    end

    set -l previous_dir (pwd)
    cd "$env_dir"; or return 1
    uv venv --python "$version" --allow-existing
    set -l status_code $status
    cd "$previous_dir"; or return 1
    return $status_code
end

function __python_venv_activate --argument-names version
    if test -z "$version"
        echo "Usage: python_venv activate <X.Y.Z>" >&2
        return 1
    end

    set -l env_dir (__python_venv_env_dir "$version"); or return 1
    set -l activate_path "$env_dir/.venv/bin/activate.fish"

    if not test -f "$activate_path"
        __python_venv_ensure "$version"; or return 1
    end

    source "$activate_path"
end

function __python_venv_deactivate
    if test -z "$VIRTUAL_ENV"
        return 0
    end

    if functions -q deactivate
        deactivate
        return $status
    end

    set -l old_virtual_env "$VIRTUAL_ENV"
    set -e VIRTUAL_ENV
    set -e VIRTUAL_ENV_PROMPT
    set -l filtered_path

    for path_entry in $PATH
        if test "$path_entry" = "$old_virtual_env/bin"; or test "$path_entry" = "$old_virtual_env/Scripts"
            continue
        end
        set filtered_path $filtered_path $path_entry
    end

    set -gx PATH $filtered_path
    return 0
end

function __python_venv_is_non_python_dep --argument-names dep
    switch $dep
        case pptxgenjs npm:pptxgenjs
            return 0
        case '*'
            return 1
    end
end

function __python_venv_add --argument-names version
    set -l deps $argv[2..-1]
    set -l python_deps
    set -l skipped_deps

    if test -z "$version"; or test (count $deps) -eq 0
        echo "Usage: python_venv add <X.Y.Z> <dep...>" >&2
        return 1
    end

    __python_venv_ensure "$version"; or return 1
    set -l env_dir (__python_venv_env_dir "$version"); or return 1

    for dep in $deps
        if __python_venv_is_non_python_dep "$dep"
            set skipped_deps $skipped_deps "$dep"
        else
            set python_deps $python_deps "$dep"
        end
    end

    if test (count $skipped_deps) -gt 0
        echo "Skipping non-Python dependencies: "(string join " " $skipped_deps)". Install with: npm install -g pptxgenjs" >&2
    end

    if test (count $python_deps) -eq 0
        return 0
    end

    set -l previous_dir (pwd)
    cd "$env_dir"; or return 1
    uv add $python_deps
    set -l status_code $status
    if test $status_code -eq 0
        uv lock
        set status_code $status
    end
    if test $status_code -eq 0
        uv sync
        set status_code $status
    end
    cd "$previous_dir"; or return 1
    return $status_code
end

function python_venv
    if test (count $argv) -lt 1
        __python_venv_usage >&2
        return 1
    end

    set -l action $argv[1]
    set -l version ""
    if test (count $argv) -ge 2
        set version $argv[2]
    end

    switch $action
        case ensure
            if test -z "$version"
                __python_venv_usage >&2
                return 1
            end
            __python_venv_ensure "$version"
        case activate
            if test -z "$version"
                __python_venv_usage >&2
                return 1
            end
            set -l target_venv (__python_venv_env_dir "$version"); or return 1
            set target_venv "$target_venv/.venv"
            if test -n "$VIRTUAL_ENV"; and test "$VIRTUAL_ENV" != "$target_venv"
                __python_venv_deactivate; or return 1
            end
            __python_venv_activate "$version"
        case deactivate
            __python_venv_deactivate
        case use
            if test -z "$version"
                __python_venv_usage >&2
                return 1
            end
            __python_venv_ensure "$version"; or return 1
            set -l target_venv (__python_venv_env_dir "$version"); or return 1
            set target_venv "$target_venv/.venv"
            if test -n "$VIRTUAL_ENV"; and test "$VIRTUAL_ENV" != "$target_venv"
                __python_venv_deactivate; or return 1
            end
            __python_venv_activate "$version"
        case add
            if test -z "$version"; or test (count $argv) -lt 3
                __python_venv_usage >&2
                return 1
            end
            __python_venv_add "$version" $argv[3..-1]
        case path
            if test -z "$version"
                __python_venv_usage >&2
                return 1
            end
            __python_venv_env_dir "$version"
        case '*'
            __python_venv_usage >&2
            return 1
    end
end
