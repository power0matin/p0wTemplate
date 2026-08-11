#!/usr/bin/env bash
set -o pipefail

SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CONFIG_FILE="/etc/3x-ui-theme-manager/config.json"
[[ -f "$CONFIG_FILE" ]] || CONFIG_FILE="$DIR/config/config.json"

source "$DIR/lib/utils.sh"
source "$DIR/lib/ui.sh"
source "$DIR/lib/filesystem.sh"
source "$DIR/lib/api.sh"
source "$DIR/lib/validator.sh"
source "$DIR/lib/semver.sh"
source "$DIR/lib/package.sh"
source "$DIR/lib/update.sh"
source "$DIR/lib/self_update.sh"
source "$DIR/lib/build.sh"

VERSION="1.3.0"
check_dependencies

count_installed_themes() {
    local install_dir
    install_dir=$(get_config_val "installDirectory" "$CONFIG_FILE")
    [[ -d "$install_dir" ]] || { printf '0'; return; }
    find "$install_dir" -mindepth 2 -maxdepth 2 -name manifest.json -type f 2>/dev/null | wc -l | tr -d ' '
}

pause_menu() {
    [[ -t 0 ]] || return 0
    printf '\n  %bPress Enter to continue...%b' "$DIM" "$RESET"
    read -r
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
            [[ -n "${2:-}" ]] || { log_error "Usage: p0wtemplate search <query>"; exit 1; }
            search_packages "$2" "$CONFIG_FILE"
            ;;
        install)
            [[ -n "${2:-}" ]] || { log_error "Usage: p0wtemplate install <package_id>[@version]"; exit 1; }
            install_package "$2" "$CONFIG_FILE"
            ;;
        remove|uninstall)
            [[ -n "${2:-}" ]] || { log_error "Usage: p0wtemplate remove <package_id>"; exit 1; }
            remove_package "$CONFIG_FILE" "$2"
            ;;
        list|ls)
            list_installed_packages "$CONFIG_FILE"
            ;;
        upgrade|update)
            upgrade_packages "$CONFIG_FILE"
            ;;
        build)
            [[ -n "${2:-}" ]] || { log_error "Usage: p0wtemplate build <path-to-theme>"; exit 1; }
            build_package "$2"
            ;;
        self-update)
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

while true; do
    show_menu "$VERSION" "$(count_installed_themes)"
    printf '  %b%s%b Select option: ' "$CYAN" "$ICON_BROWSE" "$RESET" "$CYAN" "$RESET"
    read -r choice

    case "$choice" in
        1)
            draw_progress "Fetching available themes..."
            registry_file=$(fetch_registry "$CONFIG_FILE")
            if [[ -n "$registry_file" && -f "$registry_file" ]]; then
                mapfile -t pkg_ids < <(jq -r '.packages[].id' "$registry_file")
                mapfile -t pkg_names < <(jq -r '.packages[].name' "$registry_file")
                mapfile -t pkg_desc < <(jq -r '.packages[].description' "$registry_file")
                show_theme_browser pkg_ids pkg_names pkg_desc
                printf '  %b%s%b Select theme: ' "$CYAN" "$ICON_BROWSE" "$RESET"
                read -r selection
                [[ "$selection" == '0' ]] && continue
                if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#pkg_names[@]} )); then
                    selected_idx=$((selection-1))
                    install_package "${pkg_ids[$selected_idx]}@latest" "$CONFIG_FILE" "$registry_file"
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
            list_installed_packages "$CONFIG_FILE"
            pause_menu
            ;;
        4)
            install_dir=$(get_config_val "installDirectory" "$CONFIG_FILE")
            installed_dirs=()
            if [[ -d "$install_dir" ]]; then
                while IFS= read -r dir; do installed_dirs+=("$dir"); done < <(
                    find "$install_dir" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/manifest.json' \; -print | sort
                )
            fi

            if [[ ${#installed_dirs[@]} -eq 0 ]]; then
                show_empty_state
            else
                show_installed_list_header
                counter=1
                for dir in "${installed_dirs[@]}"; do
                    id=$(jq -r '.id' "$dir/manifest.json")
                    name=$(jq -r '.name' "$dir/manifest.json")
                    version=$(jq -r '.version' "$dir/manifest.json")
                    show_installed_item "$counter" "$name" "$id" "$version"
                    ((counter++))
                done
                show_installed_list_footer "$((counter-1))" 'remove'
                printf '  %b%s%b Select theme: ' "$CYAN" "$ICON_BROWSE" "$RESET"
                read -r r_sel
                [[ "$r_sel" == '0' ]] && continue

                if [[ "$r_sel" =~ ^[0-9]+$ ]] && (( r_sel >= 1 && r_sel < counter )); then
                    sel_dir="${installed_dirs[$((r_sel-1))]}"
                    pkg_id=$(jq -r '.id' "$sel_dir/manifest.json")
                    pkg_name=$(jq -r '.name' "$sel_dir/manifest.json")
                    if show_confirm "Remove ${pkg_name}?" 'n'; then
                        remove_package "$CONFIG_FILE" "$pkg_id"
                    else
                        log_info "Cancelled."
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
