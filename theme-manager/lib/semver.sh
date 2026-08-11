#!/usr/bin/env bash

semver_compare() {
    local v1="${1#v}" v2="${2#v}"
    [[ "$v1" == "$v2" ]] && return 0
    local IFS=. i
    local -a ver1=($v1) ver2=($v2)
    for ((i=${#ver1[@]}; i<3; i++)); do ver1[i]=0; done
    for ((i=${#ver2[@]}; i<3; i++)); do ver2[i]=0; done
    for ((i=0; i<3; i++)); do
        [[ "${ver1[i]}" =~ ^[0-9]+$ && "${ver2[i]}" =~ ^[0-9]+$ ]] || return 3
        ((10#${ver1[i]} > 10#${ver2[i]})) && return 1
        ((10#${ver1[i]} < 10#${ver2[i]})) && return 2
    done
    return 0
}

semver_satisfies_min() {
    semver_compare "$1" "$2"
    local result=$?
    [[ $result -eq 0 || $result -eq 1 ]]
}
