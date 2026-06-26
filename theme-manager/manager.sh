#!/usr/bin/env bash

# Resolve base directory of the script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="/etc/3x-ui-theme-manager/config.json"

# Fallback to local config if /etc doesn't exist (for dev/testing)
if [[ ! -f "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$DIR/config/config.json"
fi

# Source libraries
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

# CLI routing
if [[ $# -gt 0 ]]; then
    case "$1" in
        search)
            if [[ -z "$2" ]]; then log_error "Usage: neotemplate search <query>"; exit 1; fi
            search_packages "$2" "$CONFIG_FILE"
            ;;
        install)
            if [[ -z "$2" ]]; then log_error "Usage: neotemplate install <package_id>[@version]"; exit 1; fi
            install_package "$2" "$CONFIG_FILE"
            ;;
        remove)
            if [[ -z "$2" ]]; then log_error "Usage: neotemplate remove <package_id>"; exit 1; fi
            remove_package "$CONFIG_FILE" "$2"
            ;;
        list)
            list_installed_packages "$CONFIG_FILE"
            ;;
        upgrade)
            upgrade_packages "$CONFIG_FILE"
            ;;
        build)
            if [[ -z "$2" ]]; then log_error "Usage: neotemplate build <path-to-theme>"; exit 1; fi
            build_package "$2"
            ;;
        self-update)
            self_update "$CONFIG_FILE"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Available commands: search, install, remove, list, upgrade, build, self-update"
            exit 1
            ;;
    esac
    exit 0
fi

# Interactive TUI routing
while true; do
    choice=$(show_menu)
    case "$choice" in
        1)
            # Remove automatic sync, just ask for package
            read -p "Enter package ID to install (e.g., glass@latest): " package_id
            if [[ -n "$package_id" ]]; then
                install_package "$package_id" "$CONFIG_FILE"
            fi
            read -p "Press enter to continue..."
            ;;
        2)
            upgrade_packages "$CONFIG_FILE"
            read -p "Press enter to continue..."
            ;;
        3)
            list_installed_packages "$CONFIG_FILE"
            read -p "Press enter to continue..."
            ;;
        4)
            list_installed_packages "$CONFIG_FILE"
            read -p "Enter package ID to remove: " remove_id
            if [[ -n "$remove_id" ]]; then
                remove_package "$CONFIG_FILE" "$remove_id"
            fi
            read -p "Press enter to continue..."
            ;;
        5)
            echo "Registry URL: $(get_config_val "repositoryUrl" "$CONFIG_FILE")"
            read -p "Press enter to continue..."
            ;;
        6)
            self_update "$CONFIG_FILE"
            read -p "Press enter to continue..."
            ;;
        7)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option."
            sleep 1
            ;;
    esac
done
