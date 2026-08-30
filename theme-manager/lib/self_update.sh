#!/usr/bin/env bash

self_update() {
    local config_file="$1" current_version="$2" manager_dir="${3:-/opt/3x-ui-theme-manager}"
    local registry_file remote_version update_url update_checksum cmp

    draw_progress "Checking for Theme Manager updates..."
    registry_file=$(fetch_registry "$config_file") || {
        show_error "Manager update failed" "Could not download the registry."
        return 1
    }

    remote_version=$(jq -r '.manager.version // empty' "$registry_file")
    update_url=$(jq -r '.manager.url // empty' "$registry_file")
    update_checksum=$(jq -r '.manager.checksum // empty' "$registry_file")
    if [[ -z "$remote_version" || -z "$update_url" || -z "$update_checksum" ]]; then
        show_error "Manager update unavailable" "The registry does not contain manager update metadata."
        return 1
    fi

    if semver_compare "$current_version" "$remote_version"; then cmp=0; else cmp=$?; fi
    if [[ $cmp -eq 3 ]]; then
        show_error "Manager update unavailable" "The local or remote manager version is invalid."
        return 1
    fi
    if [[ $cmp -eq 0 || $cmp -eq 1 ]]; then
        show_success "Manager is up to date" "Installed v$current_version · Latest v$remote_version"
        return 0
    fi

    printf '  %bUpdate available:%b v%s -> v%s\n\n' "$GREEN$BOLD" "$RESET" "$current_version" "$remote_version"
    if [[ -t 0 ]] && ! show_confirm "Update Theme Manager now?" 'y'; then
        log_info "Manager update cancelled."
        return 0
    fi

    [[ $EUID -eq 0 ]] || {
        show_error "Root required" "Run p0wtemplate with sudo/root to update the manager."
        return 1
    }

    local tmp archive extract_root source_manager candidate previous bin_dir
    tmp=$(mktemp -d) || return 1
    archive="$tmp/manager.tar.gz"
    extract_root="$tmp/source"
    mkdir -p "$extract_root"

    if ! _http_get "$(cache_busted_url "$update_url")" "$archive"; then
        safe_remove_dir "$tmp"
        show_error "Download failed" "The existing manager was not changed."
        return 1
    fi
    if ! validate_checksum "$archive" "$update_checksum"; then
        safe_remove_dir "$tmp"
        show_error "Manager verification failed" "The existing manager was not changed."
        return 1
    fi

    if ! validate_tar_entries "$archive"; then
        safe_remove_dir "$tmp"
        show_error "Unsafe update archive" "The existing manager was not changed."
        return 1
    fi

    if ! tar -xzf "$archive" -C "$extract_root"; then
        safe_remove_dir "$tmp"
        show_error "Invalid update archive" "The existing manager was not changed."
        return 1
    fi

    local manager_script
    manager_script=$(find "$extract_root" -type f -path '*/theme-manager/manager.sh' -print -quit)
    [[ -n "$manager_script" ]] || {
        safe_remove_dir "$tmp"
        show_error "Invalid update archive" "theme-manager/manager.sh was not found."
        return 1
    }
    source_manager=$(dirname "$manager_script")

    local required=(VERSION manager.sh install.sh lib/utils.sh lib/ui.sh lib/filesystem.sh lib/api.sh lib/validator.sh lib/semver.sh lib/package.sh lib/update.sh lib/self_update.sh lib/build.sh config/config.json)
    local file
    for file in "${required[@]}"; do
        [[ -f "$source_manager/$file" ]] || {
            safe_remove_dir "$tmp"
            show_error "Incomplete manager update" "Missing $file. Nothing was changed."
            return 1
        }
    done

    while IFS= read -r file; do
        bash -n "$file" || {
            safe_remove_dir "$tmp"
            show_error "Update validation failed" "A downloaded shell script has invalid syntax."
            return 1
        }
    done < <(find "$source_manager" -type f -name '*.sh' -print)

    manager_dir=$(readlink -f "$manager_dir")
    candidate="${manager_dir}.new.$$"
    previous="${manager_dir}.previous"
    safe_remove_dir "$candidate"
    cp -a "$source_manager" "$candidate" || {
        safe_remove_dir "$tmp"; safe_remove_dir "$candidate"
        show_error "Staging failed" "The existing manager was not changed."
        return 1
    }
    printf '%s\n' "$config_file" > "$candidate/.config-path" || {
        safe_remove_dir "$tmp"; safe_remove_dir "$candidate"
        show_error "Staging failed" "Could not preserve the configuration path."
        return 1
    }
    chmod 600 "$candidate/.config-path"

    chmod +x "$candidate/manager.sh" "$candidate/install.sh" "$candidate/lib/"*.sh
    safe_remove_dir "$previous"

    bin_dir="${P0W_BIN_DIR:-/usr/local/bin}"
    if ! mkdir -p "$bin_dir" ||
       [[ -e "$bin_dir/p0wtemplate" && ! -L "$bin_dir/p0wtemplate" ]] ||
       [[ -e "$bin_dir/3x-ui-theme" && ! -L "$bin_dir/3x-ui-theme" ]]; then
        safe_remove_dir "$tmp"; safe_remove_dir "$candidate"
        show_error "Update failed" "Command paths are not writable symlinks. The existing manager was not changed."
        return 1
    fi

    local p0wtemplate_link_before='__MISSING__' legacy_link_before='__MISSING__'
    [[ -L "$bin_dir/p0wtemplate" ]] && p0wtemplate_link_before=$(readlink "$bin_dir/p0wtemplate")
    [[ -L "$bin_dir/3x-ui-theme" ]] && legacy_link_before=$(readlink "$bin_dir/3x-ui-theme")
    local had_previous=false

    if [[ -d "$manager_dir" ]]; then
        mv "$manager_dir" "$previous" || {
            safe_remove_dir "$tmp"; safe_remove_dir "$candidate"
            show_error "Update failed" "Could not prepare the manager directory."
            return 1
        }
        had_previous=true
    fi

    if ! mv "$candidate" "$manager_dir"; then
        [[ "$had_previous" == true && -d "$previous" ]] && mv "$previous" "$manager_dir"
        safe_remove_dir "$tmp"
        show_error "Update failed" "The previous manager was restored."
        return 1
    fi

    if ! ln -sfn "$manager_dir/manager.sh" "$bin_dir/p0wtemplate" ||
       ! ln -sfn "$manager_dir/manager.sh" "$bin_dir/3x-ui-theme"; then
        safe_remove_dir "$manager_dir"
        [[ "$had_previous" == true && -d "$previous" ]] && mv "$previous" "$manager_dir"
        case "$p0wtemplate_link_before" in
            __MISSING__) rm -f -- "$bin_dir/p0wtemplate" ;;
            *) ln -sfn "$p0wtemplate_link_before" "$bin_dir/p0wtemplate" ;;
        esac
        case "$legacy_link_before" in
            __MISSING__) rm -f -- "$bin_dir/3x-ui-theme" ;;
            *) ln -sfn "$legacy_link_before" "$bin_dir/3x-ui-theme" ;;
        esac
        safe_remove_dir "$tmp"
        show_error "Update failed" "Command links could not be updated. The previous manager was restored."
        return 1
    fi

    local installed_version
    installed_version=$(bash "$manager_dir/manager.sh" --version 2>/dev/null | sed -n 's/.* v//p' | head -n1)
    if [[ "$installed_version" != "$remote_version" ]]; then
        safe_remove_dir "$manager_dir"
        [[ "$had_previous" == true && -d "$previous" ]] && mv "$previous" "$manager_dir"
        case "$p0wtemplate_link_before" in
            __MISSING__) rm -f -- "$bin_dir/p0wtemplate" ;;
            *) ln -sfn "$p0wtemplate_link_before" "$bin_dir/p0wtemplate" ;;
        esac
        case "$legacy_link_before" in
            __MISSING__) rm -f -- "$bin_dir/3x-ui-theme" ;;
            *) ln -sfn "$legacy_link_before" "$bin_dir/3x-ui-theme" ;;
        esac
        safe_remove_dir "$tmp"
        show_error "Update verification failed" "The previous manager was restored."
        return 1
    fi

    safe_remove_dir "$tmp"
    show_success "Manager updated" "v$current_version -> v$remote_version · Configuration preserved"
    return 10
}
