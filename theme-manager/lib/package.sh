#!/usr/bin/env bash

install_package() {
    local package_req="$1" config_file="$2" provided_registry="${3:-}"
    local package_id="${package_req%%@*}" req_version="${package_req##*@}"
    [[ "$package_id" == "$req_version" ]] && req_version='latest'

    local install_dir cache_dir registry_file package_data package_type target_version package_url package_checksum
    install_dir=$(get_config_val "installDirectory" "$config_file")
    cache_dir=$(get_config_val "cacheDirectory" "$config_file")

    if [[ -n "$provided_registry" && -f "$provided_registry" ]]; then
        registry_file="$provided_registry"
    else
        log_info "Fetching registry for $package_id..."
        registry_file=$(fetch_registry "$config_file") || return 1
    fi

    package_data=$(jq -c --arg id "$package_id" '.packages[] | select(.id == $id)' "$registry_file")
    [[ -n "$package_data" ]] || { log_error "Package '$package_id' not found in registry."; return 1; }

    package_type=$(jq -r '.type' <<<"$package_data")
    [[ "$package_type" == 'theme' ]] || { log_error "Unsupported package type: $package_type"; return 1; }

    target_version="$req_version"
    [[ "$req_version" == 'latest' ]] && target_version=$(jq -r '.latest' <<<"$package_data")
    package_url=$(jq -r --arg v "$target_version" '.versions[$v].url // empty' <<<"$package_data")
    package_checksum=$(jq -r --arg v "$target_version" '.versions[$v].checksum // empty' <<<"$package_data")
    [[ -n "$package_url" ]] || { log_error "Version '$target_version' is not available for '$package_id'."; return 1; }

    safe_create_dir "$cache_dir/archives"
    local zip_file="$cache_dir/archives/${package_id}-${target_version}.zip"
    log_info "Downloading $package_id v$target_version..."
    download_theme "$package_url" "$zip_file" || return 1

    log_info "Verifying package integrity..."
    validate_checksum "$zip_file" "$package_checksum" || return 1

    local extract_dir="$cache_dir/extract-${package_id}-$$"
    safe_remove_dir "$extract_dir"
    safe_create_dir "$extract_dir"
    extract_zip "$zip_file" "$extract_dir" || { log_error "Failed to extract package."; safe_remove_dir "$extract_dir"; return 1; }

    local target_dir="$extract_dir"
    if [[ ! -f "$target_dir/manifest.json" ]]; then
        local dirs=("$extract_dir"/*/)
        [[ ${#dirs[@]} -eq 1 ]] && target_dir="${dirs[0]}"
    fi

    validate_theme_structure "$target_dir" || { safe_remove_dir "$extract_dir"; return 1; }

    local manifest_id manifest_version
    manifest_id=$(jq -r '.id // empty' "$target_dir/manifest.json")
    manifest_version=$(jq -r '.version // empty' "$target_dir/manifest.json")
    if [[ "$manifest_id" != "$package_id" || "$manifest_version" != "$target_version" ]]; then
        log_error "Package metadata mismatch: expected $package_id v$target_version, got $manifest_id v$manifest_version."
        safe_remove_dir "$extract_dir"
        return 1
    fi

    validate_permissions "$target_dir"

    local theme_install_dir="$install_dir/$package_id"
    local action='install' old_version='' backup_path=''
    if [[ -f "$theme_install_dir/manifest.json" ]]; then
        action='update'
        old_version=$(jq -r '.version // "unknown"' "$theme_install_dir/manifest.json")
        backup_path=$(backup_theme "$theme_install_dir" "$package_id" "$old_version") || {
            log_error "Could not back up the installed theme. Update cancelled."
            safe_remove_dir "$extract_dir"
            return 1
        }
        [[ -n "$backup_path" ]] && log_info "Backup saved: $backup_path"
    fi

    local candidate="${theme_install_dir}.new.$$"
    safe_remove_dir "$candidate"
    safe_create_dir "$candidate"
    safe_copy "$target_dir/." "$candidate/" || { log_error "Failed to stage theme files."; safe_remove_dir "$candidate"; safe_remove_dir "$extract_dir"; return 1; }
    validate_theme_structure "$candidate" || { safe_remove_dir "$candidate"; safe_remove_dir "$extract_dir"; return 1; }

    safe_create_dir "$install_dir"
    if ! replace_directory_transactional "$candidate" "$theme_install_dir"; then
        log_error "Theme update failed; the previous installation was restored."
        safe_remove_dir "$candidate"
        safe_remove_dir "$extract_dir"
        return 1
    fi

    safe_remove_dir "$extract_dir"
    local theme_name
    theme_name=$(jq -r '.name // "Unknown"' "$theme_install_dir/manifest.json")
    show_install_success_message "$theme_name" "$theme_install_dir" "$action" "$old_version" "$target_version"
}

remove_package() {
    local config_file="$1" package_id="$2" install_dir theme_install_dir
    [[ -n "$package_id" ]] || { log_error "Usage: p0wtemplate remove <package_id>"; return 1; }
    install_dir=$(get_config_val "installDirectory" "$config_file")
    theme_install_dir="$install_dir/$package_id"
    [[ -d "$theme_install_dir" ]] || { log_warn "Theme '$package_id' is not installed."; return 0; }
    safe_remove_dir "$theme_install_dir"
    show_success "Theme removed" "$package_id"
}

list_installed_packages() {
    local config_file="$1" install_dir
    install_dir=$(get_config_val "installDirectory" "$config_file")
    local dirs=()
    if [[ -d "$install_dir" ]]; then
        while IFS= read -r dir; do dirs+=("$dir"); done < <(
            find "$install_dir" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/manifest.json' \; -print | sort
        )
    fi

    if [[ ${#dirs[@]} -eq 0 ]]; then
        show_empty_state
        return 0
    fi

    show_installed_list_header
    local i=1 dir id name version
    for dir in "${dirs[@]}"; do
        id=$(jq -r '.id' "$dir/manifest.json")
        name=$(jq -r '.name' "$dir/manifest.json")
        version=$(jq -r '.version' "$dir/manifest.json")
        show_installed_item "$i" "$name" "$id" "$version"
        ((i++))
    done
    show_installed_list_footer "$((i-1))" 'view'
    printf '  %bInstall directory:%b %s\n\n' "$DIM$LIGHT_GRAY" "$RESET" "$install_dir"
}
