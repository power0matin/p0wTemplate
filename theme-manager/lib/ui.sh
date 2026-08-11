#!/usr/bin/env bash

# Terminal UI for p0wTemplate Theme Manager.
# Designed to stay aligned across common SSH terminals and degrade cleanly
# when ANSI colors or UTF-8 box drawing are unavailable.

BOLD='\033[1m'
DIM='\033[2m'
WHITE='\033[38;5;255m'
LIGHT_GRAY='\033[38;5;245m'
CYAN='\033[38;5;81m'
BLUE='\033[38;5;75m'
GREEN='\033[38;5;114m'
YELLOW='\033[38;5;221m'
ORANGE='\033[38;5;209m'
RED='\033[38;5;203m'
PURPLE='\033[38;5;141m'
RESET='\033[0m'

if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    BOLD=''; DIM=''; WHITE=''; LIGHT_GRAY=''; CYAN=''; BLUE=''; GREEN=''
    YELLOW=''; ORANGE=''; RED=''; PURPLE=''; RESET=''
fi

if [[ "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" =~ [Uu][Tt][Ff]-?8 ]]; then
    BOX_TL='╭'; BOX_TR='╮'; BOX_BL='╰'; BOX_BR='╯'; BOX_H='─'; BOX_V='│'
    ICON_BROWSE='›'; ICON_UPDATE='↻'; ICON_LIST='•'; ICON_REMOVE='×'; ICON_MANAGER='↑'; ICON_EXIT='←'
    ICON_OK='✓'; ICON_WARN='!'; ICON_ERR='×'; ICON_STEP='›'
else
    BOX_TL='+'; BOX_TR='+'; BOX_BL='+'; BOX_BR='+'; BOX_H='-'; BOX_V='|'
    ICON_BROWSE='>'; ICON_UPDATE='~'; ICON_LIST='*'; ICON_REMOVE='x'; ICON_MANAGER='^'; ICON_EXIT='<'
    ICON_OK='OK'; ICON_WARN='!'; ICON_ERR='ERR'; ICON_STEP='>'
fi

ui_width() {
    local cols=72
    if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
        cols=$(tput cols 2>/dev/null || printf '72')
    fi
    (( cols < 52 )) && cols=52
    (( cols > 76 )) && cols=76
    printf '%s' "$((cols - 6))"
}

repeat_char() {
    local count="$1" char="$2" i
    for ((i=0; i<count; i++)); do
        printf '%s' "$char"
    done
}

box_border() {
    local width="${1:-$(ui_width)}" left="$2" right="$3"
    printf '  %b%s' "$DIM" "$left"
    repeat_char "$width" "$BOX_H"
    printf '%s%b\n' "$right" "$RESET"
}

box_blank() {
    local width="${1:-$(ui_width)}"
    printf '  %b%s%b%*s%b%s%b\n' "$DIM" "$BOX_V" "$RESET" "$width" '' "$DIM" "$BOX_V" "$RESET"
}

box_text() {
    local text="$1" width="${2:-$(ui_width)}" color="${3:-$WHITE}"
    local len=${#text}
    (( len > width - 4 )) && text="${text:0:$((width-7))}..." && len=${#text}
    printf '  %b%s%b  %b%s%b%*s%b%s%b\n' \
        "$DIM" "$BOX_V" "$RESET" "$color" "$text" "$RESET" "$((width-len-2))" '' "$DIM" "$BOX_V" "$RESET"
}

box_lr() {
    local left="$1" right="$2" width="${3:-$(ui_width)}"
    local left_len=${#left} right_len=${#right}
    local spaces=$((width - left_len - right_len - 4))
    (( spaces < 1 )) && spaces=1
    printf '  %b%s%b  %b%s%b%*s%b%s%b  %b%s%b\n' \
        "$DIM" "$BOX_V" "$RESET" "$BOLD$CYAN" "$left" "$RESET" "$spaces" '' \
        "$DIM$LIGHT_GRAY" "$right" "$RESET" "$DIM" "$BOX_V" "$RESET"
}

section_label() {
    local text="$1"
    printf '\n  %b%s%b\n\n' "$DIM$BOLD$LIGHT_GRAY" "$text" "$RESET"
}

menu_item() {
    local number="$1" icon="$2" title="$3" description="$4" color="$5"
    printf '  %b%2s%b  %b%s%b  %b%s%b\n' "$color$BOLD" "$number" "$RESET" "$color" "$icon" "$RESET" "$WHITE$BOLD" "$title" "$RESET"
    printf '      %b%s%b\n\n' "$DIM$LIGHT_GRAY" "$description" "$RESET"
}

draw_header() {
    local version="${1:-?}" themes_count="${2:-0}" width
    width=$(ui_width)
    [[ -t 1 ]] && clear
    printf '\n'
    box_border "$width" "$BOX_TL" "$BOX_TR"
    box_blank "$width"
    box_lr 'p0wTemplate' "Theme Manager  v${version}" "$width"
    box_text "${themes_count} theme$([[ "$themes_count" == "1" ]] || printf 's') installed" "$width" "$LIGHT_GRAY"
    box_blank "$width"
    box_border "$width" "$BOX_BL" "$BOX_BR"
}

show_menu() {
    local version="${1:-?}" themes_count="${2:-0}"
    draw_header "$version" "$themes_count"

    section_label 'THEMES'
    menu_item '1' "$ICON_BROWSE" 'Browse & Install' 'Discover and install available themes' "$CYAN"
    menu_item '2' "$ICON_UPDATE" 'Update Themes' 'Update installed themes in place' "$GREEN"
    menu_item '3' "$ICON_LIST" 'Installed Themes' 'View installed versions and paths' "$BLUE"
    menu_item '4' "$ICON_REMOVE" 'Remove Theme' 'Remove an installed theme' "$RED"

    section_label 'MANAGER'
    menu_item '5' "$ICON_MANAGER" 'Update Manager' 'Update p0wTemplate without reinstalling' "$PURPLE"
    menu_item '0' "$ICON_EXIT" 'Exit' 'Close the manager' "$LIGHT_GRAY"

    printf '  %bSelect an option and press Enter%b\n\n' "$DIM$LIGHT_GRAY" "$RESET"
}

show_theme_browser() {
    local -n ids_ref=$1 names_ref=$2 descs_ref=$3
    local count=${#names_ref[@]} width
    width=$(ui_width)

    printf '\n'
    box_border "$width" "$BOX_TL" "$BOX_TR"
    box_text 'AVAILABLE THEMES' "$width" "$GREEN$BOLD"
    box_blank "$width"

    local i num name desc
    for i in "${!names_ref[@]}"; do
        num=$((i+1)); name="${names_ref[$i]}"; desc="${descs_ref[$i]}"
        (( ${#desc} > width - 10 )) && desc="${desc:0:$((width-13))}..."
        box_text "[$num] $name" "$width" "$WHITE$BOLD"
        box_text "    $desc" "$width" "$LIGHT_GRAY"
        [[ "$i" -lt $((count-1)) ]] && box_blank "$width"
    done

    box_border "$width" "$BOX_BL" "$BOX_BR"
    printf '\n  %bSelect 1-%s, or 0 to go back%b\n\n' "$DIM$LIGHT_GRAY" "$count" "$RESET"
}

draw_progress() {
    printf '\n  %b%s%b  %s\n\n' "$CYAN" "$ICON_STEP" "$RESET" "$1"
}

show_message_box() {
    local icon="$1" color="$2" title="$3" message="$4" width
    width=$(ui_width)
    printf '\n'
    box_border "$width" "$BOX_TL" "$BOX_TR"
    box_text "$icon  $title" "$width" "$color$BOLD"
    [[ -n "$message" ]] && box_text "$message" "$width" "$LIGHT_GRAY"
    box_border "$width" "$BOX_BL" "$BOX_BR"
    printf '\n'
}

show_success() { show_message_box "$ICON_OK" "$GREEN" "$1" "${2:-}"; }
show_error()   { show_message_box "$ICON_ERR" "$RED" "$1" "${2:-}"; }
show_warning() { show_message_box "$ICON_WARN" "$YELLOW" "$1" "${2:-}"; }

show_install_success_message() {
    local theme_name="$1" install_path="$2" action="${3:-install}" old_version="${4:-}" new_version="${5:-}"
    local width
    width=$(ui_width)

    if [[ "$action" == 'update' ]]; then
        show_success 'Theme updated' "$theme_name  ${old_version:+v$old_version -> }${new_version:+v$new_version}"
        printf '  %bPath unchanged:%b %s/\n' "$DIM$LIGHT_GRAY" "$RESET" "$install_path"
        printf '  %bNo panel reconfiguration is required.%b\n\n' "$GREEN" "$RESET"
        return
    fi

    printf '\n'
    box_border "$width" "$BOX_TL" "$BOX_TR"
    box_text "$ICON_OK  Theme installed" "$width" "$GREEN$BOLD"
    box_text "$theme_name" "$width" "$WHITE$BOLD"
    box_blank "$width"
    box_text 'Apply this path in 3x-ui:' "$width" "$LIGHT_GRAY"
    box_text "${install_path}/" "$width" "$CYAN$BOLD"
    box_blank "$width"
    box_text 'Settings -> Subscription -> Profile -> Sub Theme Directory' "$width" "$LIGHT_GRAY"
    box_border "$width" "$BOX_BL" "$BOX_BR"
    printf '\n'
}

show_installed_list_header() {
    local width
    width=$(ui_width)
    printf '\n'
    box_border "$width" "$BOX_TL" "$BOX_TR"
    box_text 'INSTALLED THEMES' "$width" "$CYAN$BOLD"
    box_blank "$width"
}

show_installed_item() {
    local index="$1" name="$2" id="$3" version="$4"
    local width
    width=$(ui_width)
    box_text "[$index] $name  v$version" "$width" "$WHITE$BOLD"
    box_text "    $id" "$width" "$LIGHT_GRAY"
}

show_installed_list_footer() {
    local count="$1" action="${2:-select}" width
    width=$(ui_width)
    box_border "$width" "$BOX_BL" "$BOX_BR"
    printf '\n  %bSelect 1-%s to %s, or 0 to go back%b\n\n' "$DIM$LIGHT_GRAY" "$count" "$action" "$RESET"
}

show_empty_state() {
    show_message_box '•' "$LIGHT_GRAY" 'No themes installed' 'Use Browse & Install to add your first theme.'
}

show_confirm() {
    local message="$1" default="${2:-n}" hint
    if [[ "$default" == 'y' ]]; then hint='Y/n'; else hint='y/N'; fi
    printf '  %b?%b  %b%s%b %b[%s]%b ' "$YELLOW" "$RESET" "$WHITE" "$message" "$RESET" "$DIM" "$hint" "$RESET"
    local response
    read -r response
    [[ -z "$response" ]] && response="$default"
    [[ "$response" =~ ^[Yy]$ ]]
}

show_loading() {
    local text="$1" pid="$2" frames='|/-\\' i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r  %b%s%b %b%s%b' "$CYAN" "${frames:i++%${#frames}:1}" "$RESET" "$DIM" "$text" "$RESET"
        sleep 0.1
    done
    printf '\r%*s\r' 80 ''
}

show_status_bar() {
    printf '\n  %bp0wTemplate v%s  •  %s themes installed%b\n\n' "$DIM$LIGHT_GRAY" "$1" "$2" "$RESET"
}

log_step() {
    printf '  %b[%s/%s]%b %s\n' "$DIM" "$1" "$2" "$RESET" "$3"
}
