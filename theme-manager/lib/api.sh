#!/usr/bin/env bash

_http_get() {
    local url="$1" output="$2"
    curl --fail --silent --show-error --location \
        --retry 3 --retry-delay 1 --connect-timeout 10 --max-time 120 \
        -A "${P0W_HTTP_USER_AGENT:-p0wTemplate-Theme-Manager/1.4.0}" \
        "$url" -o "$output"
}

cache_busted_url() {
    local url="$1" separator='?'
    [[ "$url" == *\?* ]] && separator='&'
    printf '%s%st=%s\n' "$url" "$separator" "$(date +%s%N)"
}

fetch_repository() {
    local repo_url="$1" cache_file="$2" temporary
    temporary="${cache_file}.new.$$"
    if ! _http_get "$(cache_busted_url "$repo_url")" "$temporary"; then
        log_error "Failed to fetch repository data."
        rm -f -- "$temporary"
        return 1
    fi
    mv -f -- "$temporary" "$cache_file"
}

download_theme() {
    local theme_url="$1" output_file="$2" temporary
    temporary="${output_file}.new.$$"
    if ! _http_get "$(cache_busted_url "$theme_url")" "$temporary"; then
        log_error "Failed to download theme package."
        rm -f -- "$temporary"
        return 1
    fi
    mv -f -- "$temporary" "$output_file"
}

fetch_registry() {
    local config_file="$1" repo_url cache_dir registry_file
    repo_url=$(get_config_val "repositoryUrl" "$config_file")
    cache_dir=$(get_config_val "cacheDirectory" "$config_file")
    registry_file="$cache_dir/registry.json"
    safe_create_dir "$cache_dir"

    fetch_repository "$repo_url" "$registry_file" || return 1
    if ! validate_registry "$registry_file"; then
        log_error "Registry response is not valid or complete."
        rm -f "$registry_file"
        return 1
    fi
    printf '%s\n' "$registry_file"
}

search_packages() {
    local query="$1" config_file="$2" registry_file
    registry_file=$(fetch_registry "$config_file") || return 1
    printf '\n  %bSearch results for "%s"%b\n\n' "$BOLD$CYAN" "$query" "$RESET"
    jq -r --arg q "${query,,}" '
        .packages[] |
        select(((.name // "") + " " + (.description // "") + " " + (.id // "")) | ascii_downcase | contains($q)) |
        "  \(.id)  v\(.latest)\n    \(.description)\n"
    ' "$registry_file"
}
