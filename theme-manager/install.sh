#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${P0W_INSTALL_DIR:-/opt/3x-ui-theme-manager}"
CONFIG_DIR="${P0W_CONFIG_DIR:-/etc/3x-ui-theme-manager}"
BIN_DIR="${P0W_BIN_DIR:-/usr/local/bin}"
DEFAULT_CONFIG="$CONFIG_DIR/config.json"

echo "Installing p0wTemplate Theme Manager..."

if [[ $EUID -ne 0 ]]; then
    echo "This installer must be run as root."
    exit 1
fi

install_dependencies() {
    local missing=()
    for cmd in curl tar unzip zip jq sha256sum; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    [[ ${#missing[@]} -eq 0 ]] && return 0

    echo "Installing required dependencies..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        apt-get install -y curl tar unzip zip jq coreutils ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl tar unzip zip jq coreutils ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl tar unzip zip jq coreutils ca-certificates
    else
        echo "Could not install dependencies automatically. Missing: ${missing[*]}"
        exit 1
    fi
}

install_dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USE_LOCAL=false
if [[ -f "$SCRIPT_DIR/manager.sh" && -d "$SCRIPT_DIR/config" ]]; then
    USE_LOCAL=true; LOCAL_SRC_DIR="$SCRIPT_DIR"
elif [[ -f "$SCRIPT_DIR/theme-manager/manager.sh" && -d "$SCRIPT_DIR/theme-manager/config" ]]; then
    USE_LOCAL=true; LOCAL_SRC_DIR="$SCRIPT_DIR/theme-manager"
fi

TMP_DIR=''
if [[ "$USE_LOCAL" == false ]]; then
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "${TMP_DIR:-}"' EXIT
    echo "Downloading p0wTemplate..."
    curl --fail --silent --show-error --location --retry 3 \
        "https://github.com/power0matin/p0wTemplate/archive/refs/heads/main.tar.gz" \
        | tar xz -C "$TMP_DIR" --strip-components=1
    LOCAL_SRC_DIR="$TMP_DIR/theme-manager"
fi

for file in manager.sh install.sh lib/utils.sh lib/ui.sh lib/package.sh lib/update.sh lib/self_update.sh config/config.json; do
    [[ -f "$LOCAL_SRC_DIR/$file" ]] || { echo "Installer source is incomplete: $file"; exit 1; }
done

mkdir -p "$CONFIG_DIR"
CANDIDATE="${INSTALL_DIR}.new.$$"
rm -rf "$CANDIDATE"
cp -a "$LOCAL_SRC_DIR" "$CANDIDATE"
chmod +x "$CANDIDATE/manager.sh" "$CANDIDATE/install.sh" "$CANDIDATE/lib/"*.sh

while IFS= read -r file; do
    bash -n "$file"
done < <(find "$CANDIDATE" -type f -name '*.sh' -print)

PREVIOUS="${INSTALL_DIR}.previous"
rm -rf "$PREVIOUS"
[[ -d "$INSTALL_DIR" ]] && mv "$INSTALL_DIR" "$PREVIOUS"
if ! mv "$CANDIDATE" "$INSTALL_DIR"; then
    [[ -d "$PREVIOUS" ]] && mv "$PREVIOUS" "$INSTALL_DIR"
    echo "Installation failed; previous manager restored."
    exit 1
fi

# Preserve an existing user config. Only seed defaults on first install.
if [[ ! -f "$DEFAULT_CONFIG" ]]; then
    cp "$INSTALL_DIR/config/config.json" "$DEFAULT_CONFIG"
    chmod 600 "$DEFAULT_CONFIG"
fi

mkdir -p "$BIN_DIR"
ln -sfn "$INSTALL_DIR/manager.sh" "$BIN_DIR/p0wtemplate"
ln -sfn "$INSTALL_DIR/manager.sh" "$BIN_DIR/3x-ui-theme"

echo "Installation complete."
echo "Configuration: $DEFAULT_CONFIG"

if [[ -t 0 && -t 1 ]]; then
    exec "$BIN_DIR/p0wtemplate" < /dev/tty
fi
