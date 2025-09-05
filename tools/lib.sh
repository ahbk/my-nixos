#!/usr/bin/env bash

export tmpdir

PN='\033[0;35m'
PB='\033[1;35m'

RN='\033[0;31m'
RB='\033[1;31m'
GN='\033[0;32m'
GB='\033[1;32m'
YN='\033[0;33m'
YB='\033[1;33m'
BN='\033[0;34m'
BB='\033[1;34m'
NC='\033[0m'

declare -A LOG_LEVELS=(
    [debug]=0
    [focus]=99
    [info]=1
    [warning]=3
    [important]=3
    [success]=4
    [error]=4
    [off]=99
)

function cleanup {
    if [[ -n "$tmpdir" && -d "$tmpdir" ]]; then
        rm -fR "$tmpdir"
    fi
}
trap cleanup EXIT
tmpdir=$(mktemp -d)

log() {
    local level=$1
    local msg=${2:-$(cat)}

    [[ -n "$msg" ]] || return 0

    local caller=${FUNCNAME[1]}
    local depth=${#FUNCNAME[@]}

    [[ $caller != die ]] || caller=${FUNCNAME[2]}
    [[ $caller != try ]] || caller=${FUNCNAME[3]}

    [[ "$msg" == *$'\n'* ]] && {
        msg=$'\n'"$msg"
        msg="${msg//$'\n'/$'\n |        '}"
    }

    case $level in
    success) msg="[$depth]: $GB${caller}$GN: $msg$NC" ;;
    debug) msg="[$depth]: $YB${caller}$NC: $msg$NC" ;;
    focus) msg="$PB [$depth]:$PN $PN${caller}$PB: $msg$NC" ;;
    info) msg="[$depth]: $BB${caller}$BN: $msg$NC" ;;
    warning) msg="[$depth]: $YN${caller}$YB: $msg$NC" ;;
    important) msg="[$depth]: $YN${caller}$YB: $msg$NC" ;;
    error) msg="[$depth]: $RB${caller}$RN: $msg$NC" ;;
    esac

    if [[ ${LOG_LEVELS[$level]} -ge ${LOG_LEVELS[${LOG_LEVEL:-info}]:-99} ]]; then
        echo -e "$msg" >&2
    fi
}

die() {
    local exit_code=${1-$?}
    local msg=${2-}
    local fn=${3-}

    case $exit_code in
    0) log info "$msg" ;;
    *) log error "$msg (exit $exit_code)" ;;
    esac

    [[ -z "$fn" ]] || "$fn"

    exit "$exit_code"
}

try() {
    local std=$tmpdir/std.$$.$BASHPID
    local exit_code

    "$@" >"$std.out" 2>"$std.err"
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cat "$std.out"
    else
        cat "$std.out" >>"$std.err"
        die "$exit_code" "$(tr -d '\r' <"$std.err")"
    fi
}

fn-exists() {
    local fn=$1
    declare -F "$fn" >/dev/null
}

no-trailing-newline() {
    local file
    file=$(cat)
    if [[ $(tail -c1 "$file" | hexdump -C) == *"0a"* ]]; then
        die 1 "has trailing newline"
    fi
    cat "$file"
}
