#!/usr/bin/env bash

# Installation script for 3x-ui Theme Manager

echo "Installing 3x-ui Theme Manager..."

INSTALL_DIR="/opt/3x-ui-theme-manager"
CONFIG_DIR="/etc/3x-ui-theme-manager"

# Check root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root to install globally." 
   exit 1
fi

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"

# Assuming the current directory contains the source code for the manager
cp -r ./* "$INSTALL_DIR/"

# Setup default configuration
if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
    cp "$INSTALL_DIR/config/config.json" "$CONFIG_DIR/config.json"
fi

# Make scripts executable
chmod +x "$INSTALL_DIR/manager.sh"
chmod +x "$INSTALL_DIR/install.sh"
chmod +x "$INSTALL_DIR/lib/"*.sh

# Create symlink for easy access
ln -sf "$INSTALL_DIR/manager.sh" "/usr/local/bin/3x-ui-theme"

echo "Installation complete!"
echo "You can now run '3x-ui-theme' to start the manager."
