#!/usr/bin/env bash
set -o pipefail

SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

resolve_config_file() {
    if [[ -n "${P0W_CONFIG_FILE:-}" ]]; then
        printf '%s\n' "$P0W_CONFIG_FILE"
    elif [[ -n "${P0W_CONFIG_DIR:-}" ]]; then
        printf '%s/config.json\n' "$P0W_CONFIG_DIR"
    elif [[ -f "$DIR/.config-path" ]]; then
        head -n1 "$DIR/.config-path"
    elif [[ -f /etc/3x-ui-theme-manager/config.json ]]; then
        printf '%s\n' '/etc/3x-ui-theme-manager/config.json'
    else
        printf '%s\n' "$DIR/config/config.json"
    fi
}

CONFIG_FILE=$(resolve_config_file)

source "$DIR/lib/utils.sh"
source "$DIR/lib/ui.sh"
source "$DIR/lib/filesystem.sh"
source "$DIR/lib/api.sh"
source "$DIR/lib/semver.sh"
source "$DIR/lib/validator.sh"
source "$DIR/lib/package.sh"
source "$DIR/lib/update.sh"
source "$DIR/lib/self_update.sh"
source "$DIR/lib/build.sh"

VERSION=$(tr -d '[:space:]' < "$DIR/VERSION" 2>/dev/null)
semver_is_valid "$VERSION" || { log_error "Theme Manager VERSION file is invalid."; exit 1; }
check_dependencies

require_valid_config() {
    validate_config "$CONFIG_FILE" || {
        show_error "Invalid configuration" "$CONFIG_FILE"
        return 1
    }
}

count_installed_themes() {
    local install_dir
    install_dir=$(get_config_val "installDirectory" "$CONFIG_FILE")
    [[ -d "$install_dir" ]] || { printf '0'; return; }
    find "$install_dir" -mindepth 2 -maxdepth 2 -name manifest.json -type f 2>/dev/null | wc -l | tr -d ' '
}

pause_menu() {
    [[ -t 0 ]] || return 0
    printf '\n  %bPress Enter to continue...%b' "$DIM" "$RESET"
    read -r || return 0
}

read_selection() {
    local output_name="$1"
    if ! IFS= read -r "$output_name"; then
        printf '\n  %bInput closed. Exiting p0wTemplate.%b\n\n' "$DIM$LIGHT_GRAY" "$RESET"
        return 1
    fi
}

run_self_update() {
    self_update "$CONFIG_FILE" "$VERSION" "$DIR"
    local rc=$?
    if [[ $rc -eq 10 ]]; then
        printf '  %bRestarting with the updated manager...%b\n' "$DIM" "$RESET"
        exec "${P0W_BIN_DIR:-/usr/local/bin}/p0wtemplate"
    fi
    return "$rc"
}

if [[ $# -gt 0 ]]; then
    case "$1" in
        search|browse)
            require_valid_config || exit 1
            [[ -n "${2:-}" ]] || { log_error "Usage: p0wtemplate search <query>"; exit 1; }
            search_packages "$2" "$CONFIG_FILE"
            ;;
        install)
            require_valid_config || exit 1
            [[ -n "${2:-}" ]] || { log_error "Usage: p0wtemplate install <package_id>[@version]"; exit 1; }
            install_package "$2" "$CONFIG_FILE"
            ;;
        remove|uninstall)
            require_valid_config || exit 1
            [[ -n "${2:-}" ]] || { log_error "Usage: p0wtemplate remove <package_id>"; exit 1; }
            remove_package "$CONFIG_FILE" "$2"
            ;;
        list|ls)
            require_valid_config || exit 1
            list_installed_packages "$CONFIG_FILE"
            ;;
        upgrade|update)
            require_valid_config || exit 1
            upgrade_packages "$CONFIG_FILE"
            ;;
        build)
            [[ -n "${2:-}" ]] || { log_error "Usage: p0wtemplate build <path-to-theme>"; exit 1; }
            build_package "$2"
            ;;
        self-update)
            require_valid_config || exit 1
            self_update "$CONFIG_FILE" "$VERSION" "$DIR"
            rc=$?
            [[ $rc -eq 10 ]] && exit 0
            exit "$rc"
            ;;
        help|-h|--help)
            show_help
            ;;
        version|-v|--version)
            echo "p0wTemplate Theme Manager v${VERSION}"
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
    exit $?
fi

require_valid_config || exit 1

while true; do
    show_menu "$VERSION" "$(count_installed_themes)"
    printf '  %b%s%b Select option: ' "$CYAN" "$ICON_BROWSE" "$RESET"
    read_selection choice || exit 0

    case "$choice" in
        1)
            draw_progress "Fetching available themes..."
            registry_file=$(fetch_registry "$CONFIG_FILE")
            if [[ -n "$registry_file" && -f "$registry_file" ]]; then
                mapfile -t pkg_ids < <(jq -r '.packages[].id' "$registry_file")
                mapfile -t pkg_names < <(jq -r '.packages[].name' "$registry_file")
                mapfile -t pkg_desc < <(jq -r '.packages[].description' "$registry_file")
                mapfile -t pkg_versions < <(jq -r '.packages[].latest' "$registry_file")
                pkg_statuses=()
                install_dir=$(get_config_val "installDirectory" "$CONFIG_FILE")
                for i in "${!pkg_ids[@]}"; do
                    installed_manifest="$install_dir/${pkg_ids[$i]}/manifest.json"
                    status=''
                    if [[ -f "$installed_manifest" ]]; then
                        installed_version=$(jq -r '.version // empty' "$installed_manifest" 2>/dev/null)
                        if semver_is_valid "$installed_version"; then
                            if semver_compare "$installed_version" "${pkg_versions[$i]}"; then
                                status='installed'
                            else
                                compare_result=$?
                                [[ $compare_result -eq 2 ]] && status="installed v$installed_version · update available"
                                [[ $compare_result -eq 1 ]] && status="installed v$installed_version"
                            fi
                        else
                            status='invalid installed manifest'
                        fi
                    fi
                    pkg_statuses+=("$status")
                done
                show_theme_browser pkg_ids pkg_names pkg_desc pkg_versions pkg_statuses
                printf '  %b%s%b Select theme: ' "$CYAN" "$ICON_BROWSE" "$RESET"
                read_selection selection || exit 0
                [[ "$selection" == '0' ]] && continue
                if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#pkg_names[@]} )); then
                    selected_idx=$((selection-1))
                    selected_id="${pkg_ids[$selected_idx]}"
                    selected_name="${pkg_names[$selected_idx]}"
                    selected_version="${pkg_versions[$selected_idx]}"
                    if [[ -f "$install_dir/$selected_id/manifest.json" ]]; then
                        current_version=$(jq -r '.version // "unknown"' "$install_dir/$selected_id/manifest.json")
                        if [[ "$current_version" == "$selected_version" ]]; then
                            prompt="Reinstall $selected_name v$selected_version?"
                            prompt_default='n'
                        else
                            prompt="Replace $selected_name v$current_version with v$selected_version?"
                            prompt_default='y'
                        fi
                    else
                        prompt="Install $selected_name v$selected_version?"
                        prompt_default='y'
                    fi
                    if show_confirm "$prompt" "$prompt_default"; then
                        install_package "$selected_id@latest" "$CONFIG_FILE" "$registry_file"
                    else
                        log_info "Cancelled."
                    fi
                else
                    show_error "Invalid selection" "Choose a number between 1 and ${#pkg_names[@]}."
                fi
            else
                show_error "Connection failed" "Could not load the theme registry."
            fi
            pause_menu
            ;;
        2)
            upgrade_packages "$CONFIG_FILE"
            pause_menu
            ;;
        3)
            installed_dirs=()
            collect_installed_dirs "$CONFIG_FILE" installed_dirs
            if [[ ${#installed_dirs[@]} -eq 0 ]]; then
                show_empty_state
            else
                show_installed_list_header
                counter=1
                for dir in "${installed_dirs[@]}"; do
                    if validate_theme_structure "$dir" >/dev/null 2>&1; then
                        id=$(jq -r '.id' "$dir/manifest.json")
                        name=$(jq -r '.name // .id' "$dir/manifest.json")
                        version=$(jq -r '.version' "$dir/manifest.json")
                    else
                        id=$(basename -- "$dir"); name='Invalid theme'; version='?'
                    fi
                    show_installed_item "$counter" "$name" "$id" "$version" "$dir"
                    ((counter++))
                done
                show_installed_list_footer "$((counter-1))" 'view'
                printf '  %b%s%b Select theme: ' "$CYAN" "$ICON_BROWSE" "$RESET"
                read_selection view_sel || exit 0
                [[ "$view_sel" == '0' ]] && continue
                if [[ "$view_sel" =~ ^[0-9]+$ ]] && (( view_sel >= 1 && view_sel < counter )); then
                    show_installed_package_details "${installed_dirs[$((view_sel-1))]}"
                else
                    show_error "Invalid selection" "Choose a theme number from the list."
                fi
            fi
            pause_menu
            ;;
        4)
            install_dir=$(get_config_val "installDirectory" "$CONFIG_FILE")
            installed_dirs=()
            collect_installed_dirs "$CONFIG_FILE" installed_dirs

            if [[ ${#installed_dirs[@]} -eq 0 ]]; then
                show_empty_state
            else
                show_installed_list_header
                counter=1
                for dir in "${installed_dirs[@]}"; do
                    if validate_theme_structure "$dir" >/dev/null 2>&1; then
                        id=$(jq -r '.id' "$dir/manifest.json")
                        name=$(jq -r '.name // .id' "$dir/manifest.json")
                        version=$(jq -r '.version' "$dir/manifest.json")
                    else
                        id=$(basename -- "$dir"); name='Invalid theme'; version='?'
                    fi
                    show_installed_item "$counter" "$name" "$id" "$version" "$dir"
                    ((counter++))
                done
                show_installed_list_footer "$((counter-1))" 'remove'
                printf '  %b%s%b Select theme: ' "$CYAN" "$ICON_BROWSE" "$RESET"
                read_selection r_sel || exit 0
                [[ "$r_sel" == '0' ]] && continue

                if [[ "$r_sel" =~ ^[0-9]+$ ]] && (( r_sel >= 1 && r_sel < counter )); then
                    sel_dir="${installed_dirs[$((r_sel-1))]}"
                    unset pkg_id pkg_name
                    if ! validate_theme_structure "$sel_dir" >/dev/null 2>&1; then
                        show_error "Invalid installed theme" "Repair its manifest before removing it with Theme Manager."
                    else
                        pkg_id=$(jq -r '.id' "$sel_dir/manifest.json")
                        pkg_name=$(jq -r '.name // .id' "$sel_dir/manifest.json")
                    fi
                    if [[ -n "${pkg_id:-}" ]]; then
                        if [[ "$(basename -- "$sel_dir")" != "$pkg_id" ]] || ! is_valid_package_id "$pkg_id"; then
                            show_error "Unsafe installed theme" "Directory name and manifest id do not match."
                        elif show_confirm "Remove ${pkg_name}?" 'n'; then
                            remove_package "$CONFIG_FILE" "$pkg_id"
                        else
                            log_info "Cancelled."
                        fi
                    fi
                else
                    show_error "Invalid selection" "Choose a theme number from the list."
                fi
            fi
            pause_menu
            ;;
        5)
            run_self_update || true
            pause_menu
            ;;
        0)
            [[ -t 1 ]] && clear
            printf '\n  %bThanks for using p0wTemplate.%b\n\n' "$DIM$LIGHT_GRAY" "$RESET"
            exit 0
            ;;
        *)
            show_error "Invalid option" "Choose 1-5, or 0 to exit."
            sleep 1
            ;;
    esac
done
