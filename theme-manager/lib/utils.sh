#!/usr/bin/env bash

# ─── Color Definitions ───────────────────────────────────────────────────────
RED='\033[38;5;203m'
GREEN='\033[38;5;114m'
YELLOW='\033[38;5;221m'
BLUE='\033[38;5;69m'
CYAN='\033[38;5;87m'
WHITE='\033[38;5;255m'
LIGHT_GRAY='\033[38;5;249m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Logging Functions ───────────────────────────────────────────────────────

log_info() {
    printf "  ${GREEN}OK${RESET}  %s\n" "$1"
}

log_warn() {
    printf "  ${YELLOW}!${RESET}   %s\n" "$1"
}

log_error() {
    printf "  ${RED}ERR${RESET} %s\n" "$1"
}

# ─── Dependency Check ────────────────────────────────────────────────────────

check_dependencies() {
    local deps=("curl" "unzip" "jq" "sha256sum")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        printf "  ${RED}ERR${RESET} ${WHITE}Missing dependencies:${RESET}\n"
        for dep in "${missing[@]}"; do
            printf "        ${DIM}* %s${RESET}\n" "$dep"
        done
        echo ""
        printf "  ${DIM}Install them with:${RESET}\n"
        printf "  ${CYAN}apt-get install -y %s${RESET}\n" "${missing[*]}"
        echo ""
        exit 1
    fi
}

# ─── Config Reader ───────────────────────────────────────────────────────────

get_config_val() {
    local key="$1"
    local config_file="$2"

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        exit 1
    fi

    jq -r ".$key" "$config_file"
}

# ─── Help Command ────────────────────────────────────────────────────────────

show_help() {
    echo ""
    printf "  ${CYAN}${BOLD}p0wTemplate${RESET} ${DIM}Theme Manager${RESET}\n"
    echo ""
    printf "  ${WHITE}USAGE${RESET}\n"
    printf "    ${GREEN}p0wtemplate${RESET}                    Launch interactive menu\n"
    printf "    ${GREEN}p0wtemplate${RESET} ${YELLOW}<command>${RESET}       Run a command directly\n"
    echo ""
    printf "  ${WHITE}COMMANDS${RESET}\n"
    printf "    ${GREEN}browse${RESET}   ${DIM}|${RESET} ${LIGHT_GRAY}search <query>   ${RESET}  Browse available themes\n"
    printf "    ${GREEN}install${RESET}  ${DIM}|${RESET} ${LIGHT_GRAY}<id>[@version]   ${RESET}  Install a theme\n"
    printf "    ${GREEN}remove${RESET}   ${DIM}|${RESET} ${LIGHT_GRAY}<id>             ${RESET}  Remove installed theme\n"
    printf "    ${GREEN}list${RESET}     ${DIM}|${RESET} ${LIGHT_GRAY}ls               ${RESET}  List installed themes\n"
    printf "    ${GREEN}upgrade${RESET}  ${DIM}|${RESET} ${LIGHT_GRAY}update           ${RESET}  Update all themes\n"
    printf "    ${GREEN}build${RESET}    ${DIM}|${RESET} ${LIGHT_GRAY}<path>           ${RESET}  Build theme package\n"
    printf "    ${GREEN}version${RESET}  ${DIM}|${RESET} ${LIGHT_GRAY}-v, --version    ${RESET}  Show version\n"
    printf "    ${GREEN}help${RESET}     ${DIM}|${RESET} ${LIGHT_GRAY}-h, --help       ${RESET}  Show this help\n"
    echo ""
    printf "  ${WHITE}EXAMPLES${RESET}\n"
    printf "    ${DIM}p0wtemplate install neo-default@latest${RESET}\n"
    printf "    ${DIM}p0wtemplate browse glass${RESET}\n"
    printf "    ${DIM}p0wtemplate build ./themes/my-theme${RESET}\n"
    echo ""
    printf "  ${WHITE}INFO${RESET}\n"
    printf "    ${DIM}Docs:${RESET}  https://github.com/power0matin/p0wTemplate\n"
    printf "    ${DIM}Issues:${RESET} https://github.com/power0matin/p0wTemplate/issues\n"
    echo ""
}
