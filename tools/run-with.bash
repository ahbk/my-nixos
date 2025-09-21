#!/usr/bin/env bash
# run-with.bash

tmpdir=$(mktemp -d)
declare -rx tmpdir

cleanup() {
    if [[ -n "$tmpdir" && -d "$tmpdir" ]]; then
        rm -fR "$tmpdir"
    fi
}
trap cleanup EXIT

# take a list of prefixes and run their callchains
run() {
    local cmd links
    cmd="${cmd:-passthru}"

    for prefix; do
        links=$(for link in $(callchain | grep "^${prefix%:}"); do
            declare -F "$link:" && break || declare -F "$link" || continue
        done)

        [[ -n $links ]] ||
            die 1 "'$prefix' didn't match any link in the callchain:"$'\n'"$(callchain)"

        log debug "$links"

        for link in $links; do
            "$cmd" "$link"
        done
    done
}

passthru() {
    "$@"
}

with() {
    local cmd out
    for cmd; do
        out="$("$cmd")" && printf -v "${cmd//[^a-zA-Z0-9_]/_}" '%s' "$out" || exit 1
    done
}

run-with() {
    cmd=with run "$@"
}

quiet() {
    "$@" >/dev/null 2>&1
}

proxy() {
    with "$1"
    echo "${!1}"
}

tlog() {
    local level=$1
    tee >(log "$level")
}

log() {
    local level=$1

    if [[ $# -gt 1 ]]; then
        msg="$2"
    else
        msg="$(cat)"
        [[ -n "$msg" ]] || return 0
    fi

    local caller=${FUNCNAME[1]}
    local depth=${#FUNCNAME[@]}

    [[ $caller != tlog ]] || caller=${FUNCNAME[2]}
    [[ $caller != die ]] || caller=${FUNCNAME[2]}
    [[ $caller != with ]] || caller=${FUNCNAME[3]}
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
    test) msg="[test]: $TB${caller}$TN: $msg$NC" ;;
    esac

    if [[ ${LOG_LEVELS[$level]} -ge ${LOG_LEVELS[${LOG_LEVEL:-info}]:-99} ]]; then
        echo -e "$msg" >&2
    fi
}

die() {
    local exit_code=${1-$?}
    local msg=${2:-"died."}
    local fn=${3-}

    [[ -z "$fn" ]] || "$fn"

    case $exit_code in
    0) log info "$msg" ;;
    *) log error "$msg (exit $exit_code)" ;;
    esac

    exit "$exit_code"
}

try() {
    log debug "try: $*"
    local std=$tmpdir/std.$$.$BASHPID
    local exit_code=0

    "$@" >"$std.out" 2>"$std.err" || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        cat "$std.out"
    else
        cat "$std.out" >>"$std.err"
        die "$exit_code" "$(tr -d '\r' <"$std.err")"
    fi
}

fn-exists() {
    declare -F "$1"
}

fn-match() {
    declare -F | awk '{print $3}' | grep -E "$1" >/dev/null
}

trailing-newline() {
    [[ $(tail -c1 "$1" | hexdump -C) == *"0a"* ]]
}

RN='\033[0;31m'
RB='\033[1;31m'
GN='\033[0;32m'
GB='\033[1;32m'
YN='\033[0;33m'
YB='\033[1;33m'
BN='\033[0;34m'
BB='\033[1;34m'
PN='\033[0;35m'
PB='\033[1;35m'
TN='\033[0;36m'
TB='\033[1;36m'
NC='\033[0m'

declare -A LOG_LEVELS=(
    [debug]=0
    [info]=1
    [warning]=3
    [important]=3
    [success]=4
    [error]=5
    [focus]=98
    [test]=98
    [off]=99
)
