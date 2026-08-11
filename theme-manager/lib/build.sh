#!/usr/bin/env bash

build_package() {
    local source_dir="$1"
    [[ -n "$source_dir" && -d "$source_dir" ]] || { log_error "Usage: p0wtemplate build <path-to-theme-directory>"; return 1; }
    source_dir=$(cd "$source_dir" && pwd)

    validate_theme_structure "$source_dir" || return 1
    local package_id package_version
    package_id=$(jq -r '.id // empty' "$source_dir/manifest.json")
    package_version=$(jq -r '.version // empty' "$source_dir/manifest.json")
    [[ -n "$package_id" && -n "$package_version" ]] || { log_error "manifest.json must contain id and version."; return 1; }

    if ! command -v zip >/dev/null 2>&1; then
        log_error "Missing dependency: zip"
        return 1
    fi

    local staging_base staging_dir dist_dir zip_file
    staging_base=$(mktemp -d /tmp/p0wtemplate-build.XXXXXX) || return 1
    staging_dir="$staging_base/$package_id"
    mkdir -p "$staging_dir"
    safe_copy "$source_dir/." "$staging_dir/"

    # Development-only content is intentionally excluded from the install package.
    safe_remove_dir "$staging_dir/preview"
    safe_remove_dir "$staging_dir/scripts"
    rm -f "$staging_dir/mock-data.json"
    find "$staging_dir" -type f \( -name '.DS_Store' -o -name 'Thumbs.db' -o -name 'desktop.ini' \) -delete

    find "$staging_dir" -depth -type d -empty -delete

    validate_theme_structure "$staging_dir" || { safe_remove_dir "$staging_base"; return 1; }

    dist_dir="$source_dir/../dist"
    mkdir -p "$dist_dir"
    zip_file="$dist_dir/${package_id}-${package_version}.zip"
    rm -f "$zip_file"

    if (cd "$staging_dir" && zip -r -q "$zip_file" .); then
        show_success "Build complete" "$zip_file"
        sha256sum "$zip_file"
    else
        log_error "Failed to create ZIP package."
        safe_remove_dir "$staging_base"
        return 1
    fi

    safe_remove_dir "$staging_base"
}
