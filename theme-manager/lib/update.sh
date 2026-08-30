#!/usr/bin/env bash

upgrade_packages() {
    local config_file="$1" install_dir registry_file
    install_dir=$(get_config_val "installDirectory" "$config_file") || return 1

    local installed=()
    if [[ -d "$install_dir" ]]; then
        while IFS= read -r dir; do installed+=("$dir"); done < <(
            find "$install_dir" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/manifest.json' \; -print | sort
        )
    fi

    if [[ ${#installed[@]} -eq 0 ]]; then
        show_empty_state
        return 0
    fi

    draw_progress "Checking installed themes..."
    registry_file=$(fetch_registry "$config_file") || {
        show_error "Update check failed" "Could not download the theme registry."
        return 1
    }

    local update_ids=() update_names=() update_from=() update_to=()
    local check_errors=0
    local dir id name current latest package_data cmp

    for dir in "${installed[@]}"; do
        if ! validate_theme_structure "$dir" >/dev/null 2>&1; then
            log_warn "$(basename -- "$dir") has an invalid manifest; update check skipped."
            ((check_errors+=1))
            continue
        fi
        id=$(jq -r '.id // empty' "$dir/manifest.json")
        name=$(jq -r '.name // .id // "Unknown"' "$dir/manifest.json")
        current=$(jq -r '.version // "0.0.0"' "$dir/manifest.json")
        if [[ "$(basename -- "$dir")" != "$id" ]] || ! is_valid_package_id "$id"; then
            log_warn "$name has an unsafe or mismatched id; update check skipped."
            ((check_errors+=1))
            continue
        fi
        package_data=$(jq -c --arg id "$id" '.packages[] | select(.id == $id)' "$registry_file")

        if [[ -z "$package_data" ]]; then
            log_warn "$name is not present in the registry; skipped."
            ((check_errors+=1))
            continue
        fi

        latest=$(jq -r '.latest' <<<"$package_data")
        if semver_compare "$current" "$latest"; then cmp=0; else cmp=$?; fi
        case "$cmp" in
            2)
                update_ids+=("$id")
                update_names+=("$name")
                update_from+=("$current")
                update_to+=("$latest")
                ;;
            0|1) ;;
            *)
                log_warn "$name has an invalid version comparison ($current vs $latest); skipped."
                ((check_errors+=1))
                ;;
        esac
    done

    if [[ ${#update_ids[@]} -eq 0 ]]; then
        if (( check_errors > 0 )); then
            show_warning "Update check incomplete" "$check_errors installed theme(s) could not be verified."
            return 1
        fi
        show_success "Themes are up to date" "All installed themes were checked successfully."
        return 0
    fi

    printf '\n  %bUpdates available%b\n\n' "$BOLD$GREEN" "$RESET"
    local i
    for i in "${!update_ids[@]}"; do
        printf '  %b%s%b  %b%s%b  %bv%s -> v%s%b\n' \
            "$GREEN" "$ICON_UPDATE" "$RESET" "$WHITE$BOLD" "${update_names[$i]}" "$RESET" "$DIM$LIGHT_GRAY" "${update_from[$i]}" "${update_to[$i]}" "$RESET"
    done
    printf '\n'

    if [[ -t 0 ]]; then
        local confirm_rc
        if show_confirm "Update ${#update_ids[@]} theme$([[ ${#update_ids[@]} -eq 1 ]] || printf 's') now?" 'y'; then
            confirm_rc=0
        else
            confirm_rc=$?
        fi
        if [[ $confirm_rc -eq 1 ]]; then
            log_info "Update cancelled."
            return 0
        elif [[ $confirm_rc -ne 0 ]]; then
            show_warning "Update not started" "Input closed before confirmation. No theme was changed."
            return 1
        fi
    elif [[ "${P0W_ASSUME_YES:-0}" != '1' ]]; then
        show_warning "Update needs confirmation" "Run interactively or set P0W_ASSUME_YES=1 for automation."
        return 1
    fi

    local success=0 failed=0
    for i in "${!update_ids[@]}"; do
        draw_progress "Updating ${update_names[$i]}..."
        if install_package "${update_ids[$i]}@${update_to[$i]}" "$config_file" "$registry_file"; then
            ((success+=1))
        else
            ((failed+=1))
        fi
    done

    if (( failed == 0 && check_errors == 0 )); then
        show_success "Update complete" "$success theme$([[ $success -eq 1 ]] || printf 's') updated in place."
        return 0
    fi

    show_warning "Update finished with errors" "$success updated, $failed failed, $check_errors unchecked. Existing themes were preserved on failure."
    return 1
}
