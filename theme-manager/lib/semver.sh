#!/usr/bin/env bash

semver_parse() {
    local value="${1#v}" prerelease identifier major minor patch
    local pattern='^([0-9]|[1-9][0-9]*)\.([0-9]|[1-9][0-9]*)\.([0-9]|[1-9][0-9]*)(-([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
    [[ "$value" =~ $pattern ]] || return 1

    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    prerelease="${BASH_REMATCH[5]:-}"
    if [[ -n "$prerelease" ]]; then
        local IFS='.'
        for identifier in $prerelease; do
            [[ "$identifier" =~ ^[0-9]+$ && ${#identifier} -gt 1 && "$identifier" == 0* ]] && return 1
        done
    fi

    printf '%s|%s|%s|%s\n' \
        "$major" "$minor" "$patch" "$prerelease"
}

semver_is_valid() {
    semver_parse "$1" >/dev/null 2>&1
}

_semver_compare_numeric() {
    local left="$1" right="$2" LC_ALL=C
    (( ${#left} > ${#right} )) && return 1
    (( ${#left} < ${#right} )) && return 2
    [[ "$left" == "$right" ]] && return 0
    [[ "$left" > "$right" ]] && return 1
    return 2
}

_semver_compare_prerelease() {
    local left="$1" right="$2" LC_ALL=C
    [[ "$left" == "$right" ]] && return 0
    [[ -z "$left" ]] && return 1
    [[ -z "$right" ]] && return 2

    local IFS='.' i left_id right_id cmp
    local -a left_parts=($left) right_parts=($right)
    local max=${#left_parts[@]}
    (( ${#right_parts[@]} > max )) && max=${#right_parts[@]}

    for ((i=0; i<max; i++)); do
        [[ $i -ge ${#left_parts[@]} ]] && return 2
        [[ $i -ge ${#right_parts[@]} ]] && return 1
        left_id="${left_parts[$i]}"
        right_id="${right_parts[$i]}"
        [[ "$left_id" == "$right_id" ]] && continue

        if [[ "$left_id" =~ ^[0-9]+$ && "$right_id" =~ ^[0-9]+$ ]]; then
            if _semver_compare_numeric "$left_id" "$right_id"; then cmp=0; else cmp=$?; fi
            return "$cmp"
        fi
        [[ "$left_id" =~ ^[0-9]+$ ]] && return 2
        [[ "$right_id" =~ ^[0-9]+$ ]] && return 1
        [[ "$left_id" > "$right_id" ]] && return 1
        return 2
    done
    return 0
}

semver_compare() {
    local parsed_left parsed_right left_major left_minor left_patch left_pre
    local right_major right_minor right_patch right_pre cmp i
    parsed_left=$(semver_parse "$1") || return 3
    parsed_right=$(semver_parse "$2") || return 3
    IFS='|' read -r left_major left_minor left_patch left_pre <<<"$parsed_left"
    IFS='|' read -r right_major right_minor right_patch right_pre <<<"$parsed_right"

    local -a left_core=("$left_major" "$left_minor" "$left_patch")
    local -a right_core=("$right_major" "$right_minor" "$right_patch")
    for ((i=0; i<3; i++)); do
        if _semver_compare_numeric "${left_core[$i]}" "${right_core[$i]}"; then cmp=0; else cmp=$?; fi
        [[ $cmp -ne 0 ]] && return "$cmp"
    done

    if _semver_compare_prerelease "$left_pre" "$right_pre"; then return 0; else return $?; fi
}

semver_satisfies_min() {
    semver_compare "$1" "$2"
    local result=$?
    [[ $result -eq 0 || $result -eq 1 ]]
}
