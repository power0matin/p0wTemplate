#!/usr/bin/env bash

# ─── Color Definitions ───────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'

# Foreground
WHITE='\033[38;5;255m'
LIGHT_GRAY='\033[38;5;249m'
CYAN='\033[38;5;87m'
BLUE='\033[38;5;69m'
GREEN='\033[38;5;114m'
YELLOW='\033[38;5;221m'
ORANGE='\033[38;5;209m'
RED='\033[38;5;203m'
PURPLE='\033[38;5;141m'

# Background
BG_DARK='\033[48;5;235m'
BG_CARD='\033[48;5;236m'
BG_HIGHLIGHT='\033[48;5;237m'
BG_GREEN='\033[48;5;28m'
BG_BLUE='\033[48;5;24m'
BG_RED='\033[48;5;52m'
BG_YELLOW='\033[48;5;58m'

RESET='\033[0m'

# ─── Box Drawing Characters ──────────────────────────────────────────────────
BOX_TL="╭"
BOX_TR="╮"
BOX_BL="╰"
BOX_BR="╯"
BOX_H="─"
BOX_V="│"

# ─── Helper Functions ────────────────────────────────────────────────────────

# Print a horizontal line with optional width
print_line() {
    local width="${1:-58}"
    local char="${2:-$BOX_H}"
    printf "${DIM}"
    printf '%*s' "$width" '' | tr ' ' "$char"
    printf "${RESET}\n"
}

# Print a box top/bottom border
print_box_border() {
    local width="${1:-56}"
    local tl="$2"
    local tr="$3"
    printf "  ${DIM}${tl}"
    printf '%*s' "$width" '' | tr ' ' "$BOX_H"
    printf "${tr}${RESET}\n"
}

# Print empty box line
print_box_empty() {
    local width="${1:-56}"
    printf "  ${DIM}${BOX_V}${RESET}%*s${DIM}${BOX_V}${RESET}\n" "$width" ''
}

# Print centered text in box
print_box_center() {
    local text="$1"
    local width="${2:-56}"
    local color="${3:-$WHITE}"
    local text_len=${#text}
    # Remove ANSI codes for length calculation
    local clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local clean_len=${#clean_text}
    local padding=$(( (width - clean_len) / 2 ))
    local padding_right=$(( width - clean_len - padding ))
    printf "  ${DIM}${BOX_V}${RESET}%*s${color}${text}%*s${DIM}${BOX_V}${RESET}\n" "$padding" '' "$padding_right" ''
}

# Print left-aligned text in box with right padding
print_box_line() {
    local text="$1"
    local width="${2:-56}"
    local color="${3:-$LIGHT_GRAY}"
    local clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local clean_len=${#clean_text}
    local padding=$(( width - clean_len ))
    printf "  ${DIM}${BOX_V}${RESET} ${color}${text}${RESET}%*s${DIM}${BOX_V}${RESET}\n" "$padding" ''
}

# ─── Main UI Components ──────────────────────────────────────────────────────

draw_header() {
    clear
    
    # Title box
    print_box_border 56 "$BOX_TL" "$BOX_TR"
    print_box_empty 56
    print_box_center "${BOLD}${CYAN}p 0 w T e m p l a t e${RESET}" 56
    print_box_center "${DIM}${LIGHT_GRAY}Theme Manager${RESET}" 56
    print_box_empty 56
    print_box_border 56 "$BOX_BL" "$BOX_BR"
    echo ""
}

show_menu() {
    draw_header
    
    # Menu card
    print_box_border 56 "$BOX_TL" "$BOX_TR"
    print_box_line "  ${BOLD}MANAGE THEMES${RESET}" 56 "$CYAN"
    print_box_empty 56
    
    # Option 1 - Browse & Install
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}  ${GREEN}${BOLD}[1]${RESET}  ${WHITE}Browse & Install${RESET}  ${DIM}│  ${LIGHT_GRAY}Discover and install themes${RESET}  ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    
    # Option 2 - Update All
    printf "  ${DIM}${BOX_V}${RESET}  ${YELLOW}${BOLD}[2]${RESET}  ${WHITE}Update All${RESET}       ${DIM}│  ${LIGHT_GRAY}Update installed themes${RESET}       ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    
    # Option 3 - View Installed
    printf "  ${DIM}${BOX_V}${RESET}  ${CYAN}${BOLD}[3]${RESET}  ${WHITE}View Installed${RESET}   ${DIM}│  ${LIGHT_GRAY}List all installed themes${RESET}     ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    
    # Option 4 - Remove
    printf "  ${DIM}${BOX_V}${RESET}  ${ORANGE}${BOLD}[4]${RESET}  ${WHITE}Remove Theme${RESET}    ${DIM}│  ${LIGHT_GRAY}Uninstall a theme${RESET}             ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    
    # Separator
    print_box_line "  ──────────────────────────────────────────────────────" 56 "$DIM"
    print_box_empty 56
    
    # Option 5 - Exit
    printf "  ${DIM}${BOX_V}${RESET}  ${RED}${BOLD}[5]${RESET}  ${WHITE}Exit${RESET}             ${DIM}│  ${LIGHT_GRAY}Close the manager${RESET}              ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    
    print_box_border 56 "$BOX_BL" "$BOX_BR"
    echo ""
    
    # Footer hint
    printf "  ${DIM}Type ${LIGHT_GRAY}a number${DIM} and press Enter${RESET}\n"
    echo ""
}

# ─── Theme Browser UI ────────────────────────────────────────────────────────

show_theme_browser() {
    local -n ids_ref=$1
    local -n names_ref=$2
    local -n descs_ref=$3
    local count=${#names_ref[@]}
    
    echo ""
    print_box_border 56 "$BOX_TL" "$BOX_TR"
    print_box_line "  ${BOLD}AVAILABLE THEMES${RESET}" 56 "$GREEN"
    print_box_line "  ──────────────────────────────────────────────────────" 56 "$DIM"
    
    for i in "${!names_ref[@]}"; do
        local num=$((i+1))
        local name="${names_ref[$i]}"
        local desc="${descs_ref[$i]}"
        
        # Truncate description if too long
        if [[ ${#desc} -gt 36 ]]; then
            desc="${desc:0:33}..."
        fi
        
        printf "  ${DIM}${BOX_V}${RESET}  ${GREEN}${BOLD}[$num]${RESET}  ${WHITE}${BOLD}%s${RESET}\n" "$name"
        printf "  ${DIM}${BOX_V}${RESET}        ${DIM}%s${RESET}\n" "$desc"
        printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    done
    
    print_box_border 56 "$BOX_BL" "$BOX_BR"
    echo ""
    printf "  ${DIM}Select [1-$count] or ${LIGHT_GRAY}0${DIM} to go back${RESET}\n"
    echo ""
}

# ─── Progress & Status UI ────────────────────────────────────────────────────

draw_progress() {
    local text="$1"
    echo ""
    printf "  ${YELLOW}⟳  %s${RESET}\n" "$text"
    echo ""
}

draw_spinner() {
    local pid=$1
    local text=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${RESET} %s" "${spin:i++%${#spin}:1}" "$text"
        sleep 0.1
    done
    printf "\r"
}

show_success() {
    local title="$1"
    local message="$2"
    
    echo ""
    print_box_border 56 "$BOX_TL" "$BOX_TR"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${GREEN}✓${RESET}  ${WHITE}${BOLD}%s${RESET}%*s${DIM}${BOX_V}${RESET}\n" "$title" $((54-${#title})) ''
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    
    if [[ -n "$message" ]]; then
        printf "  ${DIM}${BOX_V}${RESET}     ${DIM}%s${RESET}%*s${DIM}${BOX_V}${RESET}\n" "$message" $((54-${#message})) ''
        printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    fi
    
    print_box_border 56 "$BOX_BL" "$BOX_BR"
    echo ""
}

show_error() {
    local title="$1"
    local message="$2"
    
    echo ""
    print_box_border 56 "$BOX_TL" "$BOX_TR"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${RED}✗${RESET}  ${WHITE}${BOLD}%s${RESET}%*s${DIM}${BOX_V}${RESET}\n" "$title" $((54-${#title})) ''
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    
    if [[ -n "$message" ]]; then
        printf "  ${DIM}${BOX_V}${RESET}     ${DIM}%s${RESET}%*s${DIM}${BOX_V}${RESET}\n" "$message" $((54-${#message})) ''
        printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    fi
    
    print_box_border 56 "$BOX_BL" "$BOX_BR"
    echo ""
}

show_warning() {
    local title="$1"
    local message="$2"
    
    echo ""
    print_box_border 56 "$BOX_TL" "$BOX_TR"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${YELLOW}!${RESET}  ${WHITE}${BOLD}%s${RESET}%*s${DIM}${BOX_V}${RESET}\n" "$title" $((54-${#title})) ''
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    
    if [[ -n "$message" ]]; then
        printf "  ${DIM}${BOX_V}${RESET}     ${DIM}%s${RESET}%*s${DIM}${BOX_V}${RESET}\n" "$message" $((54-${#message})) ''
        printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    fi
    
    print_box_border 56 "$BOX_BL" "$BOX_BR"
    echo ""
}

# ─── Install Success Message ─────────────────────────────────────────────────

show_install_success_message() {
    local theme_name="$1"
    local install_path="$2"
    
    echo ""
    print_box_border 56 "$BOX_TL" "$BOX_TR"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${GREEN}✓${RESET}  ${WHITE}${BOLD}THEME INSTALLED${RESET}%*s${DIM}${BOX_V}${RESET}\n" 34 ''
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${DIM}Theme:${RESET} ${CYAN}%s${RESET}%*s${DIM}${BOX_V}${RESET}\n" "$theme_name" $((46-${#theme_name})) ''
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    print_box_line "  ──────────────────────────────────────────────────────" 56 "$DIM"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${YELLOW}${BOLD}⚠  NEXT STEP REQUIRED${RESET}%*s${DIM}${BOX_V}${RESET}\n" 32 ''
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${DIM}Apply this theme in your 3x-ui panel:${RESET}           ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${DIM}1.${RESET} Open your 3x-ui panel                          ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${DIM}2.${RESET} Go to: ${WHITE}Settings → Subscription${RESET}                 ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${DIM}3.${RESET} Paste the path below:                             ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    
    # Highlighted path box
    local path_display="${install_path}/"
    printf "  ${DIM}${BOX_V}${RESET}  ${BG_BLUE}                                                              ${RESET}  ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}  ${BG_BLUE}    ${WHITE}${BOLD}%-52s${RESET}  ${DIM}${BOX_V}${RESET}\n" "$path_display"
    printf "  ${DIM}${BOX_V}${RESET}  ${BG_BLUE}                                                              ${RESET}  ${DIM}${BOX_V}${RESET}\n"
    
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${DIM}Then click ${GREEN}Save${RESET} in the panel!                      ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    print_box_border 56 "$BOX_BL" "$BOX_BR"
    echo ""
}

# ─── Installed List UI ───────────────────────────────────────────────────────

show_installed_list_header() {
    echo ""
    print_box_border 56 "$BOX_TL" "$BOX_TR"
    print_box_line "  ${BOLD}INSTALLED THEMES${RESET}" 56 "$CYAN"
    print_box_line "  ──────────────────────────────────────────────────────" 56 "$DIM"
}

show_installed_item() {
    local index="$1"
    local name="$2"
    local id="$3"
    local version="$4"
    
    printf "  ${DIM}${BOX_V}${RESET}  ${GREEN}${BOLD}[%s]${RESET}  ${WHITE}%s${RESET}  ${DIM}(%s v%s)${RESET}%*s${DIM}${BOX_V}${RESET}\n" \
        "$index" "$name" "$id" "$version" $((42-${#name}-${#id}-${#version})) ''
}

show_installed_list_footer() {
    print_box_border 56 "$BOX_BL" "$BOX_BR"
    echo ""
    printf "  ${DIM}Select [1-$1] to remove, or ${LIGHT_GRAY}0${DIM} to go back${RESET}\n"
    echo ""
}

# ─── Empty State ─────────────────────────────────────────────────────────────

show_empty_state() {
    echo ""
    print_box_border 56 "$BOX_TL" "$BOX_TR"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${DIM}No themes installed yet.${RESET}                            ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}     ${DIM}Browse & install to get started!${RESET}                    ${DIM}${BOX_V}${RESET}\n"
    printf "  ${DIM}${BOX_V}${RESET}                                                                ${DIM}${BOX_V}${RESET}\n"
    print_box_border 56 "$BOX_BL" "$BOX_BR"
    echo ""
}

# ─── Confirm Dialog ──────────────────────────────────────────────────────────

show_confirm() {
    local message="$1"
    local default="${2:-n}"
    
    local hint="Y/n"
    [[ "$default" == "y" ]] && hint="y/N"
    
    printf "\n  ${YELLOW}?${RESET}  ${WHITE}%s${RESET} ${DIM}[%s]${RESET} " "$message" "$hint"
    read -r response
    
    [[ -z "$response" ]] && response="$default"
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# ─── Loading Animation ───────────────────────────────────────────────────────

show_loading() {
    local text="$1"
    local pid=$2
    
    while kill -0 "$pid" 2>/dev/null; do
        for frame in "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"; do
            printf "\r  ${CYAN}%s${RESET} ${DIM}%s${RESET}" "$frame" "$text"
            sleep 0.08
            kill -0 "$pid" 2>/dev/null || break
        done
    done
    printf "\r"
}

# ─── Status Bar ──────────────────────────────────────────────────────────────

show_status_bar() {
    local version="$1"
    local themes_count="$2"
    
    echo ""
    printf "  ${DIM}p0wTemplate v%s │ %s themes installed${RESET}\n" "$version" "$themes_count"
    echo ""
}

# ─── Logging Functions (Colorized) ──────────────────────────────────────────
# Note: log_info, log_warn, log_error are defined in utils.sh
# These are additional UI-specific logging helpers

log_step() {
    local step="$1"
    local total="$2"
    local text="$3"
    printf "  ${DIM}[%s/%s]${RESET} %s\n" "$step" "$total" "$text"
}
