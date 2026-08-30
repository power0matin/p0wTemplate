#!/usr/bin/env bash

safe_create_dir() {
    local dir="${1:-}"
    [[ -n "$dir" ]] || { log_error "Refusing to create an empty path."; return 1; }
    [[ -d "$dir" ]] || mkdir -p -- "$dir"
}

safe_copy() {
    cp -a "$@"
}

safe_remove_dir() {
    local dir="${1:-}" resolved
    [[ -n "$dir" ]] || { log_error "Refusing to remove an empty path."; return 1; }
    resolved=$(realpath -m -- "$dir") || return 1
    [[ "$resolved" != '/' ]] || { log_error "Refusing to remove the filesystem root."; return 1; }
    [[ -e "$dir" || -L "$dir" ]] || return 0
    rm -rf -- "$dir"
}

path_is_direct_child() {
    local root child root_resolved child_resolved
    root="${1:-}"; child="${2:-}"
    [[ -n "$root" && -n "$child" ]] || return 1
    root_resolved=$(realpath -m -- "$root") || return 1
    child_resolved=$(realpath -m -- "$child") || return 1
    [[ "$child_resolved" != "$root_resolved" && "$(dirname -- "$child_resolved")" == "$root_resolved" ]]
}

ensure_directory_writable() {
    local path="${1:-}" probe
    [[ -n "$path" ]] || return 1
    probe=$(realpath -m -- "$path") || return 1
    while [[ ! -e "$probe" && "$probe" != '/' ]]; do
        probe=$(dirname -- "$probe")
    done
    [[ -d "$probe" && -w "$probe" && -x "$probe" ]]
}

extract_zip() {
    unzip -q -o "$1" -d "$2"
}

backup_theme() {
    local current_dir="$1" package_id="$2" version="$3"
    [[ -d "$current_dir" ]] || return 0

    local backup_root="${P0W_BACKUP_DIR:-/var/lib/p0wtemplate/backups}/themes/${package_id}"
    local timestamp destination
    timestamp=$(date +%Y%m%d-%H%M%S)
    destination="$backup_root/${version:-unknown}-${timestamp}"
    local suffix=1
    while [[ -e "$destination" ]]; do
        destination="$backup_root/${version:-unknown}-${timestamp}-$suffix"
        ((suffix+=1))
    done
    safe_create_dir "$backup_root"
    safe_create_dir "$destination"
    safe_copy "$current_dir/." "$destination/"
    printf '%s\n' "$destination"
}

replace_directory_transactional() {
    local candidate="$1" target="$2"
    local old="${target}.old.$$"

    [[ -d "$candidate" ]] || return 1
    safe_remove_dir "$old"

    if [[ -e "$target" ]]; then
        mv "$target" "$old" || return 1
    fi

    if mv "$candidate" "$target"; then
        safe_remove_dir "$old"
        return 0
    fi

    [[ -e "$old" ]] && mv "$old" "$target"
    return 1
}
