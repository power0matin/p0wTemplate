#!/usr/bin/env bash

upgrade_packages() {
    local config_file="$1" install_dir registry_file
    install_dir=$(get_config_val "installDirectory" "$config_file")

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
    local dir id name current latest package_data cmp

    for dir in "${installed[@]}"; do
        id=$(jq -r '.id // empty' "$dir/manifest.json")
        name=$(jq -r '.name // .id // "Unknown"' "$dir/manifest.json")
        current=$(jq -r '.version // "0.0.0"' "$dir/manifest.json")
        package_data=$(jq -c --arg id "$id" '.packages[] | select(.id == $id)' "$registry_file")

        if [[ -z "$package_data" ]]; then
            log_warn "$name is not present in the registry; skipped."
            continue
        fi

        latest=$(jq -r '.latest' <<<"$package_data")
        if semver_compare "$current" "$latest"; then cmp=0; else cmp=$?; fi
        if [[ $cmp -eq 2 ]]; then
            update_ids+=("$id")
            update_names+=("$name")
            update_from+=("$current")
            update_to+=("$latest")
        fi
    done

    if [[ ${#update_ids[@]} -eq 0 ]]; then
        show_success "Themes are up to date" "No installed theme needs an update."
        return 0
    fi

    printf '\n  %bUpdates available%b\n\n' "$BOLD$GREEN" "$RESET"
    local i
    for i in "${!update_ids[@]}"; do
        printf '  %b%s%b  %b%s%b  %bv%s -> v%s%b\n' \
            "$GREEN" "$ICON_UPDATE" "$RESET" "$WHITE$BOLD" "${update_names[$i]}" "$RESET" "$DIM$LIGHT_GRAY" "${update_from[$i]}" "${update_to[$i]}" "$RESET"
    done
    printf '\n'

    if ! show_confirm "Update ${#update_ids[@]} theme$([[ ${#update_ids[@]} -eq 1 ]] || printf 's') now?" 'y'; then
        log_info "Update cancelled."
        return 0
    fi

    local success=0 failed=0
    for i in "${!update_ids[@]}"; do
        draw_progress "Updating ${update_names[$i]}..."
        if install_package "${update_ids[$i]}@${update_to[$i]}" "$config_file" "$registry_file"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    if (( failed == 0 )); then
        show_success "Update complete" "$success theme$([[ $success -eq 1 ]] || printf 's') updated in place."
        return 0
    fi

    show_warning "Update finished with errors" "$success updated, $failed failed. Existing themes were preserved on failure."
    return 1
}
