#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODE="${1:---check}"
[[ "$MODE" == '--check' || "$MODE" == '--write' ]] || {
    echo "Usage: $0 [--check|--write]" >&2
    exit 1
}

source "$ROOT/theme-manager/lib/utils.sh"
source "$ROOT/theme-manager/lib/ui.sh"
source "$ROOT/theme-manager/lib/filesystem.sh"
source "$ROOT/theme-manager/lib/semver.sh"
source "$ROOT/theme-manager/lib/validator.sh"
source "$ROOT/theme-manager/lib/build.sh"

REGISTRY="$ROOT/registry.json"
PACKAGES_DIR="$ROOT/packages"
WORK_DIR=$(mktemp -d /tmp/p0w-release-sync.XXXXXX)
trap 'safe_remove_dir "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/theme-packages" "$PACKAGES_DIR"
jq -e '.packages | type == "array"' "$REGISTRY" >/dev/null

update_registry() {
    local filter="$1" temporary="$REGISTRY.new.$$"
    shift
    jq "$@" "$filter" "$REGISTRY" > "$temporary"
    mv -f -- "$temporary" "$REGISTRY"
}

compare_zip_contents() {
    local left="$1" right="$2" compare_root
    compare_root=$(mktemp -d "$WORK_DIR/zip-compare.XXXXXX")
    mkdir -p "$compare_root/left" "$compare_root/right"
    unzip -q "$left" -d "$compare_root/left"
    unzip -q "$right" -d "$compare_root/right"
    diff -qr "$compare_root/left" "$compare_root/right" >/dev/null
}

sync_theme() {
    local theme_dir="$1" id version package_data latest candidate destination checksum url registered_checksum cmp
    validate_theme_structure "$theme_dir"
    id=$(jq -r '.id' "$theme_dir/manifest.json")
    version=$(jq -r '.version' "$theme_dir/manifest.json")
    package_data=$(jq -c --arg id "$id" '.packages[] | select(.id == $id)' "$REGISTRY")
    [[ -n "$package_data" ]] || { log_error "Theme '$id' is missing from registry.json"; return 1; }
    latest=$(jq -r '.latest' <<<"$package_data")

    P0W_DIST_DIR="$WORK_DIR/theme-packages" build_package "$theme_dir" >/dev/null
    candidate="$WORK_DIR/theme-packages/$id-$version.zip"
    destination="$PACKAGES_DIR/$id-$version.zip"
    checksum=$(sha256sum "$candidate" | awk '{print $1}')
    url="https://raw.githubusercontent.com/power0matin/p0wTemplate/main/packages/$id-$version.zip"

    if jq -e --arg version "$version" '.versions[$version] != null' <<<"$package_data" >/dev/null; then
        destination="$PACKAGES_DIR/$(jq -r --arg version "$version" '.versions[$version].url | split("/")[-1]' <<<"$package_data")"
        [[ -f "$destination" ]] || { log_error "Registered package is missing: $destination"; return 1; }
        validate_zip_entries "$destination"
        compare_zip_contents "$candidate" "$destination" || {
            log_error "$id source changed without a version bump (still v$version)."
            return 1
        }
        registered_checksum=$(jq -r --arg version "$version" '.versions[$version].checksum // empty' <<<"$package_data")
        checksum=$(sha256sum "$destination" | awk '{print $1}')
        if [[ "$registered_checksum" != "$checksum" || "$latest" != "$version" ]]; then
            [[ "$MODE" == '--write' ]] || { log_error "$id v$version release metadata is out of sync."; return 1; }
            update_registry '
                .packages |= map(if .id == $id then
                    .latest = $version |
                    .versions[$version].checksum = $checksum
                else . end)
            ' --arg id "$id" --arg version "$version" --arg checksum "$checksum"
        fi
        log_info "$id v$version is synchronized."
        return 0
    fi

    if semver_compare "$version" "$latest"; then cmp=0; else cmp=$?; fi
    [[ $cmp -eq 1 ]] || { log_error "$id v$version must be newer than registry latest v$latest."; return 1; }
    [[ "$MODE" == '--write' ]] || { log_error "$id v$version has not been released."; return 1; }
    cp "$candidate" "$destination"
    update_registry '
        .packages |= map(if .id == $id then
            .latest = $version |
            .versions[$version] = {url: $url, checksum: $checksum}
        else . end)
    ' --arg id "$id" --arg version "$version" --arg url "$url" --arg checksum "$checksum"
    log_info "Prepared $id v$version."
}

build_manager_archive() {
    local version="$1" output="$2" staging="$WORK_DIR/manager-stage"
    safe_remove_dir "$staging"
    mkdir -p "$staging/p0wTemplate-manager-$version/theme-manager/lib" "$staging/p0wTemplate-manager-$version/theme-manager/config"
    cp "$ROOT/theme-manager/VERSION" "$ROOT/theme-manager/manager.sh" "$ROOT/theme-manager/install.sh" \
        "$staging/p0wTemplate-manager-$version/theme-manager/"
    cp "$ROOT/theme-manager/lib/"*.sh "$staging/p0wTemplate-manager-$version/theme-manager/lib/"
    cp "$ROOT/theme-manager/config/config.json" "$staging/p0wTemplate-manager-$version/theme-manager/config/"
    find "$staging" -type f -exec chmod 644 {} +
    chmod 755 "$staging/p0wTemplate-manager-$version/theme-manager/manager.sh" \
        "$staging/p0wTemplate-manager-$version/theme-manager/install.sh" \
        "$staging/p0wTemplate-manager-$version/theme-manager/lib/"*.sh
    find "$staging" -exec touch -h -t 198001010000.00 {} +
    (cd "$staging" && tar --sort=name --mtime='UTC 1980-01-01' --owner=0 --group=0 --numeric-owner \
        -cf - "p0wTemplate-manager-$version" | gzip -n -9 > "$output")
}

compare_manager_contents() {
    local left="$1" right="$2" compare_root
    compare_root=$(mktemp -d "$WORK_DIR/manager-compare.XXXXXX")
    mkdir -p "$compare_root/left" "$compare_root/right"
    tar -xzf "$left" -C "$compare_root/left" --strip-components=1
    tar -xzf "$right" -C "$compare_root/right" --strip-components=1
    diff -qr "$compare_root/left" "$compare_root/right" >/dev/null
}

sync_manager() {
    local version registered_version candidate destination checksum registered_checksum url cmp
    version=$(tr -d '[:space:]' < "$ROOT/theme-manager/VERSION")
    semver_is_valid "$version" || { log_error "Invalid Theme Manager version: $version"; return 1; }
    registered_version=$(jq -r '.manager.version' "$REGISTRY")
    candidate="$WORK_DIR/p0wtemplate-manager-$version.tar.gz"
    destination="$PACKAGES_DIR/p0wtemplate-manager-$version.tar.gz"
    url="https://raw.githubusercontent.com/power0matin/p0wTemplate/main/packages/p0wtemplate-manager-$version.tar.gz"
    build_manager_archive "$version" "$candidate"

    if [[ "$version" == "$registered_version" ]]; then
        destination="$PACKAGES_DIR/$(jq -r '.manager.url | split("/")[-1]' "$REGISTRY")"
        [[ -f "$destination" ]] || { log_error "Registered manager package is missing: $destination"; return 1; }
        compare_manager_contents "$candidate" "$destination" || {
            log_error "Theme Manager source changed without a VERSION bump (still v$version)."
            return 1
        }
        checksum=$(sha256sum "$destination" | awk '{print $1}')
        registered_checksum=$(jq -r '.manager.checksum // empty' "$REGISTRY")
        [[ "$registered_checksum" == "$checksum" ]] || {
            [[ "$MODE" == '--write' ]] || { log_error "Manager checksum is out of sync."; return 1; }
            update_registry '.manager.checksum = $checksum' --arg checksum "$checksum"
        }
        log_info "Theme Manager v$version is synchronized."
        return 0
    fi

    if semver_compare "$version" "$registered_version"; then cmp=0; else cmp=$?; fi
    [[ $cmp -eq 1 ]] || { log_error "Theme Manager v$version must be newer than v$registered_version."; return 1; }
    [[ "$MODE" == '--write' ]] || { log_error "Theme Manager v$version has not been released."; return 1; }
    cp "$candidate" "$destination"
    checksum=$(sha256sum "$destination" | awk '{print $1}')
    update_registry '.manager = {version: $version, url: $url, checksum: $checksum}' \
        --arg version "$version" --arg url "$url" --arg checksum "$checksum"
    log_info "Prepared Theme Manager v$version."
}

for theme_dir in "$ROOT"/themes/*; do
    [[ -d "$theme_dir" && -f "$theme_dir/manifest.json" ]] || continue
    sync_theme "$theme_dir"
done
sync_manager
validate_registry "$REGISTRY"
log_info "Release metadata and packages are fully synchronized."
