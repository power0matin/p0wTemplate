#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${P0W_INSTALL_DIR:-/opt/3x-ui-theme-manager}"
CONFIG_DIR="${P0W_CONFIG_DIR:-/etc/3x-ui-theme-manager}"
BIN_DIR="${P0W_BIN_DIR:-/usr/local/bin}"
DEFAULT_CONFIG="$CONFIG_DIR/config.json"
REGISTRY_URL="${P0W_REGISTRY_URL:-https://raw.githubusercontent.com/power0matin/p0wTemplate/main/registry.json}"

validate_target_path() {
    local label="$1" value="$2" relative
    relative="${value#/}"
    if [[ "$value" != /* || "$value" == '/' || "$relative" != */* || "$value" == *$'\n'* || "/$value/" == */../* ]]; then
        echo "$label must be a safe absolute path below the filesystem root: $value"
        exit 1
    fi
}

validate_target_path 'P0W_INSTALL_DIR' "$INSTALL_DIR"
validate_target_path 'P0W_CONFIG_DIR' "$CONFIG_DIR"
validate_target_path 'P0W_BIN_DIR' "$BIN_DIR"
if [[ "$INSTALL_DIR" == "$CONFIG_DIR" || "$INSTALL_DIR" == "$BIN_DIR" ||
      "$CONFIG_DIR" == "$INSTALL_DIR/"* || "$BIN_DIR" == "$INSTALL_DIR/"* ]]; then
    echo 'Install, configuration and binary paths must not overlap.'
    exit 1
fi

echo "Installing p0wTemplate Theme Manager..."

if [[ $EUID -ne 0 ]]; then
    echo "This installer must be run as root."
    exit 1
fi

install_dependencies() {
    local missing=()
    for cmd in curl tar unzip zip zipinfo jq sha256sum; do
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
    registry_file="$TMP_DIR/registry.json"
    archive="$TMP_DIR/manager.tar.gz"
    extract_root="$TMP_DIR/source"
    mkdir -p "$extract_root"

    echo "Downloading release metadata..."
    curl --fail --silent --show-error --location --retry 3 \
        --connect-timeout 10 --max-time 120 \
        "${REGISTRY_URL}?t=$(date +%s%N)" -o "$registry_file"
    manager_version=$(jq -er '.manager.version' "$registry_file")
    manager_url=$(jq -er '.manager.url' "$registry_file")
    manager_checksum=$(jq -er '.manager.checksum' "$registry_file")
    [[ "$manager_checksum" =~ ^[a-fA-F0-9]{64}$ ]] || { echo "Manager checksum is missing or invalid."; exit 1; }

    echo "Downloading p0wTemplate Theme Manager v$manager_version..."
    separator='?'; [[ "$manager_url" == *\?* ]] && separator='&'
    curl --fail --silent --show-error --location --retry 3 \
        --connect-timeout 10 --max-time 180 \
        "${manager_url}${separator}t=$(date +%s%N)" -o "$archive"
    actual_checksum=$(sha256sum "$archive" | awk '{print $1}')
    [[ "$actual_checksum" == "$manager_checksum" ]] || { echo "Manager archive checksum mismatch."; exit 1; }

    archive_listing=$(tar -tvzf "$archive") || { echo "Manager package is not a valid archive."; exit 1; }
    if awk 'substr($1, 1, 1) == "l" || substr($1, 1, 1) == "h" { found=1 } END { exit !found }' <<<"$archive_listing"; then
        echo "Manager archive contains a symbolic or hard link."
        exit 1
    fi
    while IFS= read -r archive_entry; do
        [[ "$archive_entry" != /* && "/$archive_entry" != */../* ]] || { echo "Manager archive contains an unsafe path."; exit 1; }
    done < <(tar -tzf "$archive")
    tar -xzf "$archive" -C "$extract_root"
    manager_script=$(find "$extract_root" -type f -path '*/theme-manager/manager.sh' -print -quit)
    [[ -n "$manager_script" ]] || { echo "Downloaded archive does not contain theme-manager/manager.sh"; exit 1; }
    LOCAL_SRC_DIR=$(dirname "$manager_script")
fi

for file in VERSION manager.sh install.sh lib/utils.sh lib/ui.sh lib/filesystem.sh lib/api.sh lib/validator.sh lib/semver.sh lib/package.sh lib/update.sh lib/self_update.sh lib/build.sh config/config.json; do
    [[ -f "$LOCAL_SRC_DIR/$file" ]] || { echo "Installer source is incomplete: $file"; exit 1; }
done

mkdir -p "$(dirname -- "$INSTALL_DIR")"
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
had_previous=false
[[ -d "$INSTALL_DIR" ]] && { mv "$INSTALL_DIR" "$PREVIOUS"; had_previous=true; }
if ! mv "$CANDIDATE" "$INSTALL_DIR"; then
    [[ "$had_previous" == true && -d "$PREVIOUS" ]] && mv "$PREVIOUS" "$INSTALL_DIR"
    echo "Installation failed; previous manager restored."
    exit 1
fi

finish_installation() {
    mkdir -p "$CONFIG_DIR" || return 1
    if [[ ! -f "$DEFAULT_CONFIG" ]]; then
        cp "$INSTALL_DIR/config/config.json" "$DEFAULT_CONFIG" || return 1
        chmod 600 "$DEFAULT_CONFIG" || return 1
    fi
    printf '%s\n' "$DEFAULT_CONFIG" > "$INSTALL_DIR/.config-path" || return 1
    chmod 600 "$INSTALL_DIR/.config-path" || return 1
    mkdir -p "$BIN_DIR" || return 1
    [[ ! -e "$BIN_DIR/p0wtemplate" || -L "$BIN_DIR/p0wtemplate" ]] || return 1
    [[ ! -e "$BIN_DIR/3x-ui-theme" || -L "$BIN_DIR/3x-ui-theme" ]] || return 1
    ln -sfn "$INSTALL_DIR/manager.sh" "$BIN_DIR/p0wtemplate" || return 1
    ln -sfn "$INSTALL_DIR/manager.sh" "$BIN_DIR/3x-ui-theme" || return 1
}

config_created=false
[[ -f "$DEFAULT_CONFIG" ]] || config_created=true
p0wtemplate_link_before='__MISSING__'
legacy_link_before='__MISSING__'
[[ -L "$BIN_DIR/p0wtemplate" ]] && p0wtemplate_link_before=$(readlink "$BIN_DIR/p0wtemplate")
[[ -L "$BIN_DIR/3x-ui-theme" ]] && legacy_link_before=$(readlink "$BIN_DIR/3x-ui-theme")
[[ -e "$BIN_DIR/p0wtemplate" && ! -L "$BIN_DIR/p0wtemplate" ]] && p0wtemplate_link_before='__NONLINK__'
[[ -e "$BIN_DIR/3x-ui-theme" && ! -L "$BIN_DIR/3x-ui-theme" ]] && legacy_link_before='__NONLINK__'

if ! finish_installation; then
    rm -rf "$INSTALL_DIR"
    [[ "$had_previous" == true && -d "$PREVIOUS" ]] && mv "$PREVIOUS" "$INSTALL_DIR"
    case "$p0wtemplate_link_before" in
        __MISSING__) rm -f -- "$BIN_DIR/p0wtemplate" ;;
        __NONLINK__) : ;;
        *) ln -sfn "$p0wtemplate_link_before" "$BIN_DIR/p0wtemplate" ;;
    esac
    case "$legacy_link_before" in
        __MISSING__) rm -f -- "$BIN_DIR/3x-ui-theme" ;;
        __NONLINK__) : ;;
        *) ln -sfn "$legacy_link_before" "$BIN_DIR/3x-ui-theme" ;;
    esac
    [[ "$config_created" == false ]] || rm -f -- "$DEFAULT_CONFIG"
    echo "Installation failed during finalization; previous manager restored."
    exit 1
fi

echo "Installation complete."
echo "Configuration: $DEFAULT_CONFIG"

if [[ -t 1 && -r /dev/tty ]]; then
    exec "$BIN_DIR/p0wtemplate" < /dev/tty
fi
