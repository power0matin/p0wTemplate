#!/usr/bin/env bash

safe_create_dir() {
    [[ -d "$1" ]] || mkdir -p "$1"
}

safe_copy() {
    cp -a "$@"
}

safe_remove_dir() {
    local dir="$1"
    [[ -n "$dir" && "$dir" != '/' && -d "$dir" ]] && rm -rf -- "$dir"
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
    safe_create_dir "$backup_root"
    safe_copy "$current_dir" "$destination"
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
