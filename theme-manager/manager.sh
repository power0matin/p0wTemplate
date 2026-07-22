#!/usr/bin/env bash

# ─── Resolve Script Directory ────────────────────────────────────────────────
SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
DIR="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
CONFIG_FILE="/etc/3x-ui-theme-manager/config.json"

# Fallback to local config for dev/testing
if [[ ! -f "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$DIR/config/config.json"
fi

# ─── Source Libraries ────────────────────────────────────────────────────────
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

check_dependencies

# ─── Version ─────────────────────────────────────────────────────────────────
VERSION="1.2.0"

# ─── CLI Routing ─────────────────────────────────────────────────────────────
if [[ $# -gt 0 ]]; then
    case "$1" in
        search|browse)
            if [[ -z "$2" ]]; then
                log_error "Usage: p0wtemplate search <query>"
                exit 1
            fi
            search_packages "$2" "$CONFIG_FILE"
            ;;
        install)
            if [[ -z "$2" ]]; then
                log_error "Usage: p0wtemplate install <package_id>[@version]"
                exit 1
            fi
            install_package "$2" "$CONFIG_FILE"
            ;;
        remove|uninstall)
            if [[ -z "$2" ]]; then
                log_error "Usage: p0wtemplate remove <package_id>"
                exit 1
            fi
            remove_package "$CONFIG_FILE" "$2"
            ;;
        list|ls)
            list_installed_packages "$CONFIG_FILE"
            ;;
        upgrade|update)
            upgrade_packages "$CONFIG_FILE"
            ;;
        build)
            if [[ -z "$2" ]]; then
                log_error "Usage: p0wtemplate build <path-to-theme>"
                exit 1
            fi
            build_package "$2"
            ;;
        self-update)
            self_update "$CONFIG_FILE"
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
    exit 0
fi

# ─── Interactive TUI ─────────────────────────────────────────────────────────
while true; do
    show_menu
    read -p "  ▸ Select option: " choice
    
    case "$choice" in
        1)
            # Browse & Install
            draw_progress "Fetching available themes..."
            registry_file=$(fetch_registry "$CONFIG_FILE")
            
            if [[ -n "$registry_file" && -f "$registry_file" ]]; then
                mapfile -t pkg_ids < <(jq -r '.packages[].id' "$registry_file")
                mapfile -t pkg_names < <(jq -r '.packages[].name' "$registry_file")
                mapfile -t pkg_desc < <(jq -r '.packages[].description' "$registry_file")
                
                show_theme_browser pkg_ids pkg_names pkg_desc
                read -p "  ▸ Select theme: " selection
                
                if [[ "$selection" == "0" ]]; then
                    continue
                fi
                
                if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#pkg_names[@]}" ]; then
                    selected_idx=$((selection-1))
                    package_id="${pkg_ids[$selected_idx]}@latest"
                    
                    echo ""
                    draw_progress "Installing ${pkg_names[$selected_idx]}..."
                    install_package "$package_id" "$CONFIG_FILE"
                else
                    show_error "Invalid Selection" "Please enter a number between 1 and ${#pkg_names[@]}"
                fi
            else
                show_error "Connection Failed" "Could not load themes. Check your internet connection."
            fi
            
            printf "\n  ${DIM}Press Enter to continue...${RESET}"
            read -r
            ;;
        
        2)
            # Update All
            upgrade_packages "$CONFIG_FILE"
            printf "\n  ${DIM}Press Enter to continue...${RESET}"
            read -r
            ;;
        
        3)
            # View Installed
            list_installed_packages "$CONFIG_FILE"
            printf "\n  ${DIM}Press Enter to continue...${RESET}"
            read -r
            ;;
        
        4)
            # Remove Theme
            install_dir=$(get_config_val "installDirectory" "$CONFIG_FILE")
            
            if [[ -d "$install_dir" ]]; then
                mapfile -t installed_dirs < <(find "$install_dir" -mindepth 1 -maxdepth 1 -type d -exec test -f {}/manifest.json \; -print)
                
                if [[ ${#installed_dirs[@]} -eq 0 ]]; then
                    show_empty_state
                else
                    show_installed_list_header
                    
                    local counter=1
                    for dir in "${installed_dirs[@]}"; do
                        if [[ -f "$dir/manifest.json" ]]; then
                            local id=$(jq -r '.id' "$dir/manifest.json")
                            local name=$(jq -r '.name' "$dir/manifest.json")
                            local version=$(jq -r '.version' "$dir/manifest.json")
                            show_installed_item "$counter" "$name" "$id" "$version"
                            ((counter++))
                        fi
                    done
                    
                    show_installed_list_footer "$((counter-1))"
                    read -p "  ▸ Select theme to remove: " r_sel
                    
                    if [[ "$r_sel" == "0" ]]; then
                        continue
                    fi
                    
                    if [[ "$r_sel" =~ ^[0-9]+$ ]] && [ "$r_sel" -ge 1 ] && [ "$r_sel" -le "$((counter-1))" ]; then
                        sel_idx=$((r_sel-1))
                        sel_dir="${installed_dirs[$sel_idx]}"
                        pkg_id=$(jq -r '.id' "$sel_dir/manifest.json")
                        
                        if [[ -n "$pkg_id" ]]; then
                            if show_confirm "Remove $(jq -r '.name' "$sel_dir/manifest.json")?" "n"; then
                                remove_package "$CONFIG_FILE" "$pkg_id"
                            else
                                log_info "Cancelled."
                            fi
                        fi
                    else
                        show_error "Invalid Selection" "Please enter a valid number"
                    fi
                fi
            else
                show_empty_state
            fi
            
            printf "\n  ${DIM}Press Enter to continue...${RESET}"
            read -r
            ;;
        
        0)
            # Exit
            clear
            echo ""
            printf "  ${DIM}Thanks for using ${CYAN}p0wTemplate${DIM}!${RESET}\n"
            echo ""
            exit 0
            ;;

        *)
            show_error "Invalid Option" "Please select 1-4 or 0 to exit"
            sleep 1
            ;;
    esac
done
