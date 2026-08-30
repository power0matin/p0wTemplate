#!/usr/bin/env bash

validate_theme_structure() {
    local theme_dir="$1"
    [[ -f "$theme_dir/manifest.json" ]] || { log_error "manifest.json missing."; return 1; }
    [[ -f "$theme_dir/index.html" ]] || { log_error "index.html missing."; return 1; }
    jq -e . "$theme_dir/manifest.json" >/dev/null 2>&1 || { log_error "manifest.json is not valid JSON."; return 1; }

    local id version
    id=$(jq -r '.id // empty' "$theme_dir/manifest.json")
    version=$(jq -r '.version // empty' "$theme_dir/manifest.json")
    [[ -n "$id" && -n "$version" ]] || { log_error "manifest.json must contain id and version."; return 1; }
    is_valid_package_id "$id" || { log_error "Theme id '$id' is not safe."; return 1; }
    semver_is_valid "$version" || { log_error "Theme version '$version' is not valid SemVer."; return 1; }
    return 0
}

validate_checksum() {
    local file="$1" expected_hash="$2"
    [[ "$expected_hash" =~ ^[a-fA-F0-9]{64}$ ]] || {
        log_error "Package checksum is missing or invalid. Installation stopped."
        return 1
    }
    local actual_hash
    actual_hash=$(sha256sum "$file" | awk '{print $1}')
    [[ "$actual_hash" == "$expected_hash" ]] || {
        log_error "Checksum mismatch. Package was not installed."
        return 1
    }
}

validate_zip_entries() {
    local archive="$1" entry listing
    unzip -tqq "$archive" >/dev/null 2>&1 || { log_error "Package is not a valid ZIP archive."; return 1; }
    listing=$(zipinfo -l "$archive") || { log_error "Could not inspect package entries."; return 1; }
    if awk 'substr($1, 1, 1) == "l" { found=1 } END { exit !found }' <<<"$listing"; then
        log_error "Theme packages may not contain symbolic links."
        return 1
    fi
    while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        if [[ "$entry" == /* || "$entry" == *\\* || "/$entry" == */../* || "$entry" == '..' ]]; then
            log_error "Unsafe archive entry: $entry"
            return 1
        fi
    done < <(unzip -Z1 "$archive")
}

validate_tar_entries() {
    local archive="$1" entry listing
    listing=$(tar -tvzf "$archive") || { log_error "Manager package is not a valid gzip-compressed TAR archive."; return 1; }
    if awk 'substr($1, 1, 1) == "l" || substr($1, 1, 1) == "h" { found=1 } END { exit !found }' <<<"$listing"; then
        log_error "Manager packages may not contain symbolic or hard links."
        return 1
    fi
    while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        if [[ "$entry" == /* || "/$entry" == */../* ]]; then
            log_error "Unsafe manager package entry: $entry"
            return 1
        fi
    done < <(tar -tzf "$archive")
}

validate_config() {
    local config_file="$1" repository_url install_dir cache_dir install_resolved cache_resolved
    jq -e . "$config_file" >/dev/null 2>&1 || { log_error "Config is not valid JSON: $config_file"; return 1; }
    repository_url=$(get_config_val repositoryUrl "$config_file") || return 1
    install_dir=$(get_config_val installDirectory "$config_file") || return 1
    cache_dir=$(get_config_val cacheDirectory "$config_file") || return 1

    if [[ "$repository_url" != https://* && "${P0W_ALLOW_INSECURE_HTTP:-0}" != '1' ]]; then
        log_error "repositoryUrl must use HTTPS."
        return 1
    fi
    [[ "$install_dir" == /* && "$install_dir" != '/' ]] || { log_error "installDirectory must be a safe absolute path."; return 1; }
    [[ "$cache_dir" == /* && "$cache_dir" != '/' ]] || { log_error "cacheDirectory must be a safe absolute path."; return 1; }
    [[ "$install_dir" != *$'\n'* && "$cache_dir" != *$'\n'* ]] || { log_error "Configuration paths may not contain newlines."; return 1; }
    install_resolved=$(realpath -m -- "$install_dir") || return 1
    cache_resolved=$(realpath -m -- "$cache_dir") || return 1
    if [[ "$install_resolved" == "$cache_resolved" || "$install_resolved" == "$cache_resolved/"* || "$cache_resolved" == "$install_resolved/"* ]]; then
        log_error "installDirectory and cacheDirectory must not overlap."
        return 1
    fi
}

validate_registry() {
    local registry_file="$1" registry_version manager_version manager_checksum package_id latest version checksum url cmp
    jq -e '
        (.version | type == "string") and
        (.manager | type == "object") and
        (.manager.version | type == "string") and
        (.manager.url | type == "string" and startswith("https://")) and
        (.manager.checksum | type == "string") and
        (.packages | type == "array") and
        ([.packages[].id] | length == (unique | length)) and
        all(.packages[];
            (.id | type == "string") and
            (.name | type == "string") and
            (.type == "theme") and
            (.latest | type == "string") and
            (.versions | type == "object") and
            (.latest as $latest | .versions[$latest] != null) and
            all(.versions[];
                (.url | type == "string" and startswith("https://")) and
                (.checksum | type == "string")
            )
        )
    ' "$registry_file" >/dev/null 2>&1 || { log_error "Registry schema is invalid."; return 1; }

    registry_version=$(jq -r '.version' "$registry_file")
    manager_version=$(jq -r '.manager.version' "$registry_file")
    manager_checksum=$(jq -r '.manager.checksum' "$registry_file")
    semver_is_valid "$registry_version" || { log_error "Registry schema version is invalid."; return 1; }
    semver_is_valid "$manager_version" || { log_error "Registry manager version is invalid."; return 1; }
    [[ "$manager_checksum" =~ ^[a-fA-F0-9]{64}$ ]] || { log_error "Registry manager checksum is invalid."; return 1; }

    while IFS=$'\t' read -r package_id latest version url checksum; do
        is_valid_package_id "$package_id" || { log_error "Unsafe package id in registry: $package_id"; return 1; }
        semver_is_valid "$latest" || { log_error "Invalid latest version for $package_id: $latest"; return 1; }
        semver_is_valid "$version" || { log_error "Invalid version for $package_id: $version"; return 1; }
        [[ "$checksum" =~ ^[a-fA-F0-9]{64}$ ]] || { log_error "Invalid checksum for $package_id v$version"; return 1; }
        if semver_compare "$latest" "$version"; then cmp=0; else cmp=$?; fi
        [[ $cmp -eq 0 || $cmp -eq 1 ]] || { log_error "Latest version for $package_id is older than registered v$version"; return 1; }
    done < <(jq -r '.packages[] as $package | $package.versions | to_entries[] | [$package.id, $package.latest, .key, .value.url, .value.checksum] | @tsv' "$registry_file")
}

validate_permissions() {
    local theme_dir="$1"
    find "$theme_dir" -type f -exec chmod 644 {} +
    find "$theme_dir" -type d -exec chmod 755 {} +
}
