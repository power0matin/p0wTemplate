#!/usr/bin/env bash

# Shared logging and utility helpers. UI colors are redefined by ui.sh with
# terminal capability detection; these defaults keep direct library use safe.
RED='\033[38;5;203m'
GREEN='\033[38;5;114m'
YELLOW='\033[38;5;221m'
BLUE='\033[38;5;75m'
CYAN='\033[38;5;81m'
WHITE='\033[38;5;255m'
LIGHT_GRAY='\033[38;5;245m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()  { printf '  %b✓%b  %s\n' "$GREEN" "$RESET" "$1"; }
log_warn()  { printf '  %b!%b  %s\n' "$YELLOW" "$RESET" "$1"; }
log_error() { printf '  %b×%b  %s\n' "$RED" "$RESET" "$1" >&2; }

check_dependencies() {
    local deps=(curl tar unzip zip jq sha256sum)
    local missing=() dep
    for dep in "${deps[@]}"; do
        command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        printf '  Install them, or rerun the official installer as root.\n'
        exit 1
    fi
}

get_config_val() {
    local key="$1" config_file="$2"
    [[ -f "$config_file" ]] || { log_error "Config file not found: $config_file"; return 1; }
    jq -r --arg key "$key" '.[$key]' "$config_file"
}

show_help() {
    cat <<'HELP'

  p0wTemplate Theme Manager

  USAGE
    p0wtemplate                         Launch interactive menu
    p0wtemplate <command> [arguments]   Run a command directly

  THEMES
    search <query>                      Search available themes
    install <id>[@version]              Install or replace a theme
    update | upgrade                    Update installed themes in place
    list | ls                           List installed themes
    remove <id>                         Remove an installed theme

  MANAGER
    self-update                         Update Theme Manager in place
    version                             Show installed manager version

  DEVELOPMENT
    build <path>                        Validate and build a theme package

  OTHER
    help                                Show this help

HELP
}
