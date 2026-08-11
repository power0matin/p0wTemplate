#!/usr/bin/env bash

validate_theme_structure() {
    local theme_dir="$1"
    [[ -f "$theme_dir/manifest.json" ]] || { log_error "manifest.json missing."; return 1; }
    [[ -f "$theme_dir/index.html" ]] || { log_error "index.html missing."; return 1; }
    jq -e . "$theme_dir/manifest.json" >/dev/null 2>&1 || { log_error "manifest.json is not valid JSON."; return 1; }

    local id version
    id=$(jq -r '.id // empty' "$theme_dir/manifest.json")
    version=$(jq -r '.version // empty' "$theme_dir/manifest.json")
    [[ -n "$id" && -n "$version" ]] || { log_error "manifest.json must contain id and version."; return 1; }
    return 0
}

validate_checksum() {
    local file="$1" expected_hash="$2"
    [[ -n "$expected_hash" ]] || { log_warn "Package has no checksum in registry; verification skipped."; return 0; }
    local actual_hash
    actual_hash=$(sha256sum "$file" | awk '{print $1}')
    [[ "$actual_hash" == "$expected_hash" ]] || {
        log_error "Checksum mismatch. Package was not installed."
        return 1
    }
}

validate_permissions() {
    local theme_dir="$1"
    find "$theme_dir" -type f -exec chmod 644 {} +
    find "$theme_dir" -type d -exec chmod 755 {} +
}
