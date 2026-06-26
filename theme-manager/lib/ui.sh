#!/usr/bin/env bash

draw_header() {
    clear
    echo -e "${BLUE}NeoTemplate - Package Manager${NC}"
    echo "─────────────────────"
}

show_menu() {
    draw_header
    echo "1 Install Package"
    echo "2 Upgrade Packages"
    echo "3 Installed Packages"
    echo "4 Remove Package"
    echo "5 View Registry URL"
    echo "6 Self-Update Manager"
    echo "7 Exit"
    echo
    read -p "Select an option: " choice
    echo "$choice"
}

draw_progress() {
    local text="$1"
    echo -e "${YELLOW}${text}...${NC}"
}

show_install_success_message() {
    local theme_name="$1"
    local install_path="$2"
    
    echo ""
    echo "────────────────────────────────────"
    echo ""
    echo -e "${GREEN}Theme Installed Successfully${NC}"
    echo ""
    echo "Theme:"
    echo "$theme_name"
    echo ""
    echo "Installed Path:"
    echo "$install_path"
    echo ""
    echo "────────────────────────────────────"
    echo ""
    echo -e "${YELLOW}Final Step${NC}"
    echo ""
    echo "Open your 3x-ui panel and navigate to:"
    echo ""
    echo "Panel Settings"
    echo "→ Subscription"
    echo "→ Profile"
    echo "→ Sub Theme Directory"
    echo ""
    echo "Paste the following path:"
    echo ""
    echo "$install_path"
    echo ""
    echo "Save the settings."
    echo ""
    echo "Your new subscription page is now ready."
    echo ""
    echo "────────────────────────────────────"
}
