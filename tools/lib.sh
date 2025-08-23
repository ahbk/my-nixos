#!/usr/bin/env bash

log() {
    # bold or not bold red green yellow and normal colors
    local RN='\033[0;31m'
    local RB='\033[1;31m'
    local GN='\033[0;32m'
    local GB='\033[1;32m'
    local YN='\033[0;33m'
    local YB='\033[1;33m'
    local BN='\033[0;34m'
    local BB='\033[1;34m'
    local NC='\033[0m'
    local log=false
    local msg=$1
    local level=$2
    local caller=${FUNCNAME[1]}
    local depth=${#FUNCNAME[@]}

    if [[ $caller == die ]]; then
        caller=${FUNCNAME[2]}
    fi

    if [[ $caller == try ]]; then
        caller=${FUNCNAME[3]}
    fi

    case $level in
    success) msg="[$depth]: $GB${caller}$GN: $msg$NC" ;;
    debug) msg="[$depth]: $YB${caller}$NC: $msg$NC" ;;
    info) msg="[$depth]: $BB${caller}$BN: $msg$NC" ;;
    warning) msg="[$depth]: $YN${caller}$YB: $msg$NC" ;;
    error) msg="[$depth]: $RB${caller}$RN: $msg$NC" ;;
    esac

    case $level in
    warning | error | success | info)
        log=true
        ;;
    *)
        if [[ ${DEBUG:-} == true ]]; then
            log=true
        fi
        ;;
    esac

    if [[ $log == true ]]; then
        echo -e "$msg" >&2
    fi
}

die() {
    local exit_code=${1-$?}
    local msg=${2-}
    local fn=${3-}

    case $exit_code in
    0) log "$msg" info ;;
    *) log "$msg (exit $exit_code)" error ;;
    esac

    [[ -n "$fn" ]] && "$fn"

    log "exit code $exit_code" debug
    exit "$exit_code"
}

try() {
    local stderr_file stdout_file exit_code
    stderr_file=$(mktemp)
    stdout_file=$(mktemp)
    "$@" >"$stdout_file" 2>"$stderr_file"
    exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        cat "$stdout_file"
    else
        die "$exit_code" "$(tr -d '\r' <"$stderr_file")"
    fi
    rm "$stderr_file"
}

fn-exists() {
    local fn=$1
    declare -F "$fn" >/dev/null
}
