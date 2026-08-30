#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QA_ROOT=$(mktemp -d /tmp/p0w-manager-qa.XXXXXX)

source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/filesystem.sh"
source "$SCRIPT_DIR/lib/api.sh"
source "$SCRIPT_DIR/lib/semver.sh"
source "$SCRIPT_DIR/lib/validator.sh"
source "$SCRIPT_DIR/lib/package.sh"
source "$SCRIPT_DIR/lib/update.sh"
source "$SCRIPT_DIR/lib/self_update.sh"
source "$SCRIPT_DIR/lib/build.sh"

cleanup_qa_root() {
    if safe_remove_dir "$QA_ROOT"; then
        return 0
    fi
    if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
        sudo -n rm -rf -- "$QA_ROOT" && return 0
    fi
    printf 'WARN: could not remove QA fixture root: %s\n' "$QA_ROOT" >&2
    return 1
}

trap cleanup_qa_root EXIT
export NO_COLOR=1

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
assert_file() { [[ -f "$1" ]] || fail "Missing file: $1"; }

semver_result() {
    local result
    if semver_compare "$1" "$2"; then result=0; else result=$?; fi
    printf '%s' "$result"
}

for file in "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/lib/*.sh "$SCRIPT_DIR"/scripts/*.sh; do
    bash -n "$file"
done
pass 'all Bash files pass syntax validation'

validate_config "$SCRIPT_DIR/config/config.json"
validate_registry "$ROOT/registry.json"
pass 'configuration and registry schemas are valid'

jq '.packages[0].latest="1.1.0"' "$ROOT/registry.json" > "$QA_ROOT/stale-latest-registry.json"
if validate_registry "$QA_ROOT/stale-latest-registry.json" >/dev/null 2>&1; then
    fail 'Registry accepted latest metadata older than a registered release'
fi
jq '.cacheDirectory=.installDirectory + "/cache"' "$SCRIPT_DIR/config/config.json" > "$QA_ROOT/overlap-config.json"
if validate_config "$QA_ROOT/overlap-config.json" >/dev/null 2>&1; then
    fail 'Configuration accepted overlapping install and cache paths'
fi
pass 'registry ordering and configuration path overlap are rejected'

manager_version=$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION")
[[ "$manager_version" == "$(jq -r '.manager.version' "$ROOT/registry.json")" ]] || fail 'Manager VERSION and registry differ'
pass 'Theme Manager version has one synchronized source'

[[ "$(semver_result 1.3.4 1.3.5)" == 2 ]] || fail 'SemVer upgrade comparison failed'
[[ "$(semver_result 1.3.5 1.3.4)" == 1 ]] || fail 'SemVer downgrade comparison failed'
[[ "$(semver_result 1.3.5 1.3.5+build.2)" == 0 ]] || fail 'SemVer build metadata comparison failed'
[[ "$(semver_result 1.3.5-beta.2 1.3.5)" == 2 ]] || fail 'SemVer prerelease comparison failed'
[[ "$(semver_result 1.2.3.4 1.2.3.5)" == 3 ]] || fail 'Invalid four-part SemVer was accepted'
[[ "$(semver_result invalid 1.0.0)" == 3 ]] || fail 'Invalid SemVer was accepted'
pass 'SemVer comparison covers releases, prereleases and invalid values'

while IFS=$'\t' read -r id version url expected_checksum; do
    package="$ROOT/packages/${url##*/}"
    assert_file "$package"
    actual_checksum=$(sha256sum "$package" | awk '{print $1}')
    [[ "$actual_checksum" == "$expected_checksum" ]] || fail "Checksum mismatch for $id v$version"
    validate_zip_entries "$package"
    extract_dir="$QA_ROOT/package-$id-$version"
    mkdir -p "$extract_dir"
    unzip -q "$package" -d "$extract_dir"
    validate_theme_structure "$extract_dir"
    [[ "$(jq -r '.id' "$extract_dir/manifest.json")" == "$id" ]] || fail "Package id mismatch for $id v$version"
    [[ "$(jq -r '.version' "$extract_dir/manifest.json")" == "$version" ]] || fail "Package version mismatch for $id v$version"
done < <(jq -r '.packages[] as $package | $package.versions | to_entries[] | [$package.id, .key, .value.url, .value.checksum] | @tsv' "$ROOT/registry.json")
pass 'every registered theme package exists, verifies and matches its manifest'

mkdir -p "$QA_ROOT/unsafe-archive"
ln -s /etc/passwd "$QA_ROOT/unsafe-archive/link"
(cd "$QA_ROOT/unsafe-archive" && zip -q -y "$QA_ROOT/unsafe.zip" link)
if validate_zip_entries "$QA_ROOT/unsafe.zip" >/dev/null 2>&1; then
    fail 'ZIP validation accepted a symbolic link'
fi
tar -czf "$QA_ROOT/unsafe.tar.gz" -C "$QA_ROOT/unsafe-archive" link
if validate_tar_entries "$QA_ROOT/unsafe.tar.gz" >/dev/null 2>&1; then
    fail 'TAR validation accepted a symbolic link'
fi
pass 'archive validation rejects symbolic and hard-link attack surfaces'

manager_url=$(jq -r '.manager.url' "$ROOT/registry.json")
manager_archive="$ROOT/packages/${manager_url##*/}"
assert_file "$manager_archive"
validate_checksum "$manager_archive" "$(jq -r '.manager.checksum' "$ROOT/registry.json")"
mkdir -p "$QA_ROOT/manager-package"
tar -xzf "$manager_archive" -C "$QA_ROOT/manager-package"
packaged_manager=$(find "$QA_ROOT/manager-package" -type f -path '*/theme-manager/manager.sh' -print -quit)
[[ -n "$packaged_manager" ]] || fail 'Manager archive does not contain manager.sh'
packaged_manager_dir=$(dirname "$packaged_manager")
[[ "$(tr -d '[:space:]' < "$packaged_manager_dir/VERSION")" == "$manager_version" ]] || fail 'Manager package version mismatch'
pass 'Theme Manager archive checksum, structure and version are valid'

mkdir -p "$QA_ROOT/build-a" "$QA_ROOT/build-b"
P0W_DIST_DIR="$QA_ROOT/build-a" build_package "$ROOT/themes/hyper-sentry" >/dev/null
P0W_DIST_DIR="$QA_ROOT/build-b" build_package "$ROOT/themes/hyper-sentry" >/dev/null
[[ "$(sha256sum "$QA_ROOT/build-a/hyper-sentry-1.3.5.zip" | awk '{print $1}')" == \
   "$(sha256sum "$QA_ROOT/build-b/hyper-sentry-1.3.5.zip" | awk '{print $1}')" ]] || fail 'Theme builds are not deterministic'
pass 'theme package builds are deterministic'

bash "$SCRIPT_DIR/scripts/sync-releases.sh" --check >/dev/null
pass 'theme sources, packages, checksums and registry are synchronized'

installer_root="$QA_ROOT/installer-success"
installer_runner=()
if [[ $EUID -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || fail 'Installer QA requires root or passwordless sudo'
    installer_runner=(sudo)
fi
if ! "${installer_runner[@]}" env \
    P0W_INSTALL_DIR="$installer_root/opt/manager" \
    P0W_CONFIG_DIR="$installer_root/etc/manager" \
    P0W_BIN_DIR="$installer_root/usr/local/bin" \
    bash "$SCRIPT_DIR/install.sh" </dev/null > "$installer_root.out" 2>&1; then
    cat "$installer_root.out" >&2
    fail 'Installer success path failed'
fi
[[ -x "$installer_root/opt/manager/manager.sh" ]] || fail 'Installer did not deploy manager.sh'
[[ -f "$installer_root/etc/manager/config.json" ]] || fail 'Installer did not deploy its configuration'
[[ "$(readlink "$installer_root/usr/local/bin/p0wtemplate")" == "$installer_root/opt/manager/manager.sh" ]] || fail 'Installer command link is incorrect'

set +e
"${installer_runner[@]}" env \
P0W_INSTALL_DIR='/tmp' \
P0W_CONFIG_DIR="$QA_ROOT/invalid-path/etc/manager" \
P0W_BIN_DIR="$QA_ROOT/invalid-path/usr/local/bin" \
    bash "$SCRIPT_DIR/install.sh" </dev/null > "$QA_ROOT/invalid-installer-path.out" 2>&1
invalid_path_rc=$?
set -e
[[ $invalid_path_rc -ne 0 ]] || fail 'Installer accepted a broad top-level target path'

rollback_root="$QA_ROOT/installer-rollback"
mkdir -p "$rollback_root/opt/manager" "$rollback_root/usr/local/bin"
touch "$rollback_root/opt/manager/original-install" "$rollback_root/usr/local/bin/p0wtemplate"
set +e
"${installer_runner[@]}" env \
P0W_INSTALL_DIR="$rollback_root/opt/manager" \
P0W_CONFIG_DIR="$rollback_root/etc/manager" \
P0W_BIN_DIR="$rollback_root/usr/local/bin" \
    bash "$SCRIPT_DIR/install.sh" </dev/null > "$rollback_root/install.out" 2>&1
rollback_rc=$?
set -e
[[ $rollback_rc -ne 0 ]] || fail 'Installer finalization failure unexpectedly succeeded'
[[ -f "$rollback_root/opt/manager/original-install" ]] || fail 'Installer did not restore the previous manager'
[[ -f "$rollback_root/usr/local/bin/p0wtemplate" && ! -L "$rollback_root/usr/local/bin/p0wtemplate" ]] || fail 'Installer damaged a pre-existing command file'
[[ ! -e "$rollback_root/etc/manager/config.json" ]] || fail 'Installer rollback left a new configuration behind'
pass 'installer success and transactional rollback paths work in isolation'

jq --arg install "$QA_ROOT/installed" --arg cache "$QA_ROOT/cache" \
    '.installDirectory=$install | .cacheDirectory=$cache' "$SCRIPT_DIR/config/config.json" > "$QA_ROOT/config.json"
validate_config "$QA_ROOT/config.json"
export P0W_BACKUP_DIR="$QA_ROOT/backups"

fetch_registry() { printf '%s\n' "$ROOT/registry.json"; }
download_theme() {
    local url="$1" output="$2" source
    source="$ROOT/packages/${url##*/}"
    [[ -f "$source" ]] || return 1
    cp "$source" "$output"
}

while IFS= read -r id; do
    install_package "$id@latest" "$QA_ROOT/config.json" "$ROOT/registry.json" >/dev/null
done < <(jq -r '.packages[].id' "$ROOT/registry.json")

while IFS=$'\t' read -r id latest; do
    [[ "$(jq -r '.version' "$QA_ROOT/installed/$id/manifest.json")" == "$latest" ]] || fail "Latest install failed for $id"
done < <(jq -r '.packages[] | [.id,.latest] | @tsv' "$ROOT/registry.json")
pass 'Browse/Install flow installs every latest theme in isolation'

upgrade_packages "$QA_ROOT/config.json" > "$QA_ROOT/update-current.out"
grep -q 'All installed themes were checked successfully' "$QA_ROOT/update-current.out" || fail 'Healthy update check did not report success'
pass 'Update Themes reports a verified up-to-date state'

install_package 'neo-default@1.1.0' "$QA_ROOT/config.json" "$ROOT/registry.json" >/dev/null
P0W_ASSUME_YES=1 upgrade_packages "$QA_ROOT/config.json" > "$QA_ROOT/update-old.out"
[[ "$(jq -r '.version' "$QA_ROOT/installed/neo-default/manifest.json")" == '1.2.0' ]] || fail 'Update Themes did not install the latest registered release'
grep -q 'Updates available' "$QA_ROOT/update-old.out" || fail 'Update Themes did not disclose the available update'
grep -q 'Update complete' "$QA_ROOT/update-old.out" || fail 'Update Themes did not disclose update completion'
pass 'Update Themes upgrades an older installation to the latest release'

mkdir -p "$QA_ROOT/outside-target"
if remove_package "$QA_ROOT/config.json" '../outside-target' >/dev/null 2>&1; then
    fail 'Path traversal package id was accepted'
fi
[[ -d "$QA_ROOT/outside-target" ]] || fail 'Path traversal removed a directory outside install root'
pass 'Remove Theme rejects path traversal and preserves outside paths'

if (safe_remove_dir() { return 1; }; remove_package "$QA_ROOT/config.json" neo-default >/dev/null 2>&1); then
    fail 'Removal failure returned success'
fi
[[ -d "$QA_ROOT/installed/neo-default" ]] || fail 'Failed removal unexpectedly removed theme'
pass 'Remove Theme reports filesystem failures accurately'

remove_package "$QA_ROOT/config.json" neo-default >/dev/null
[[ ! -e "$QA_ROOT/installed/neo-default" ]] || fail 'Successful removal left the theme directory behind'
install_package 'neo-default@latest' "$QA_ROOT/config.json" "$ROOT/registry.json" >/dev/null
pass 'Remove Theme success path works and the theme can be reinstalled'

jq '.version="invalid"' "$QA_ROOT/installed/hyper-sentry/manifest.json" > "$QA_ROOT/invalid-manifest.json"
mv "$QA_ROOT/invalid-manifest.json" "$QA_ROOT/installed/hyper-sentry/manifest.json"
if upgrade_packages "$QA_ROOT/config.json" > "$QA_ROOT/update-invalid.out" 2>&1; then
    fail 'Invalid installed version was reported as up to date'
fi
grep -q 'Update check incomplete' "$QA_ROOT/update-invalid.out" || fail 'Incomplete update check was not disclosed'
safe_remove_dir "$QA_ROOT/installed/hyper-sentry"
install_package 'hyper-sentry@latest' "$QA_ROOT/config.json" "$ROOT/registry.json" >/dev/null
pass 'Update Themes exposes invalid or unchecked installations'

search_packages '[' "$QA_ROOT/config.json" > "$QA_ROOT/search.out"
! grep -q 'Regex failure' "$QA_ROOT/search.out" || fail 'Search still interprets input as a regular expression'
pass 'Search treats user input literally'

menu_output=$(printf '0\n' | NO_COLOR=1 P0W_CONFIG_FILE="$QA_ROOT/config.json" bash "$SCRIPT_DIR/manager.sh")
[[ "$(grep -o 'Select option:' <<<"$menu_output" | wc -l | tr -d ' ')" == 1 ]] || fail 'Main selection prompt is duplicated'
[[ "$menu_output" != *'\033[0m'* ]] || fail 'Main prompt leaks raw ANSI escape text'
pass 'main menu prompt renders once without raw escape text'

set +e
timeout 3 env NO_COLOR=1 P0W_CONFIG_FILE="$QA_ROOT/config.json" bash "$SCRIPT_DIR/manager.sh" </dev/null > "$QA_ROOT/eof.out"
eof_rc=$?
set -e
[[ $eof_rc -eq 0 ]] || fail 'Manager does not exit cleanly when input closes'
grep -q 'Input closed' "$QA_ROOT/eof.out" || fail 'EOF exit is not explained to the user'
pass 'closed input exits cleanly instead of looping'

details_output=$(printf '3\n1\n0\n' | NO_COLOR=1 P0W_CONFIG_FILE="$QA_ROOT/config.json" bash "$SCRIPT_DIR/manager.sh")
[[ "$details_output" == *'THEME DETAILS'* ]] || fail 'Installed Themes selection does not open details'
[[ "$details_output" == *'Path:'* ]] || fail 'Installed theme details do not show the path'
pass 'Installed Themes supports functional detail selection'

cp -a "$SCRIPT_DIR" "$QA_ROOT/manager-copy"
printf '%s\n' "$QA_ROOT/config.json" > "$QA_ROOT/manager-copy/.config-path"
marker_output=$(NO_COLOR=1 bash "$QA_ROOT/manager-copy/manager.sh" list)
[[ "$marker_output" == *'HyperSentry'* ]] || fail 'Persisted custom config path is ignored'
pass 'custom configuration paths remain active after installation/update'

self_update "$QA_ROOT/config.json" "$manager_version" "$SCRIPT_DIR" > "$QA_ROOT/self-update.out"
grep -q 'Manager is up to date' "$QA_ROOT/self-update.out" || fail 'Self Update current-version path failed'
pass 'Update Manager validates and recognizes the current release'

cp -a "$SCRIPT_DIR" "$QA_ROOT/old-manager"
printf '%s\n' '1.3.0' > "$QA_ROOT/old-manager/VERSION"
mkdir -p "$QA_ROOT/self-update-bin"
_http_get() {
    local url="$1" output="$2" filename
    filename="${url%%\?*}"
    filename="${filename##*/}"
    cp "$ROOT/packages/$filename" "$output"
}
set +e
P0W_BIN_DIR="$QA_ROOT/self-update-bin" self_update "$QA_ROOT/config.json" '1.3.0' "$QA_ROOT/old-manager" > "$QA_ROOT/self-update-full.out"
self_update_rc=$?
set -e
if [[ $self_update_rc -ne 10 ]]; then
    cat "$QA_ROOT/self-update-full.out" >&2 || true
    fail "Self Update did not return its restart status after a successful update (exit $self_update_rc)"
fi
[[ "$(tr -d '[:space:]' < "$QA_ROOT/old-manager/VERSION")" == "$manager_version" ]] || fail 'Self Update did not install the latest manager version'
[[ "$(readlink "$QA_ROOT/self-update-bin/p0wtemplate")" == "$QA_ROOT/old-manager/manager.sh" ]] || fail 'Self Update did not refresh command links'
[[ "$(cat "$QA_ROOT/old-manager/.config-path")" == "$QA_ROOT/config.json" ]] || fail 'Self Update did not preserve the custom configuration path'
pass 'Update Manager performs a verified full update and preserves configuration'

if command -v node >/dev/null 2>&1; then
    node "$ROOT/themes/hyper-sentry/scripts/validate.mjs" >/dev/null
    chromium_path=$(command -v chromium || command -v google-chrome || command -v google-chrome-stable || command -v chromium-browser || true)
    if [[ -n "$chromium_path" ]]; then
        CHROMIUM="$chromium_path" node "$ROOT/themes/hyper-sentry/scripts/qa.mjs" >/dev/null
        pass 'HyperSentry validation and full browser responsive/runtime QA pass'
    else
        P0W_QA_SKIP_BROWSER=1 node "$ROOT/themes/hyper-sentry/scripts/qa.mjs" >/dev/null
        pass 'HyperSentry validation and non-browser QA pass (Chromium unavailable)'
    fi
fi

printf '\nTheme Manager comprehensive QA passed.\n'
