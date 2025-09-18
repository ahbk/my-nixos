#!/usr/bin/env bash
# run-with.bash

run() {
    local context cmd
    for context; do
        printf -v "$command_context_identifier" '%s' "$context"
        with callchain
        cmd="$(find-first "$callchain" fn-exists)"
        $cmd
    done
}

with() {
    local cmd var out
    for cmd; do
        var=${cmd//-/_}
        var=${var//:/_}
        if ! out="$("$cmd")"; then
            exit 1
        fi
        printf -v "$var" '%s' "$out"
    done
}

run-with() {
    local context cmd
    for context; do
        printf -v "$command_context_identifier" '%s' "$context"
        with callchain
        for item in $callchain; do
            fn-exists "$item" >/dev/null || continue
            with "$item"
        done
    done
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
    local level=$1 msg=${2:-$(cat)}

    [[ -n "$msg" ]] || return 0

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
    local fn=$1
    declare -F "$fn" >/dev/null && echo "$fn"
}

fn-match() {
    local pat=$1
    declare -F | awk '{print $3}' | grep -E "$pat" >/dev/null
}

trailing-newline() {
    local file
    file=$1
    if [[ $(tail -c1 "$file" | hexdump -C) == *"0a"* ]]; then
        return 0
    fi
    return 1
}

find-first() {
    local chain=$1 cmd=$2 index

    read -r index <<<"$chain"

    if grep -Fxq "$index" "$cache"; then
        log debug "cache hit: $index"
        grep -A1 -Fx "$index" "$cache" | tail -n1
        return 0
    fi

    for item in $chain; do
        result=$("$cmd" "$item" 2>/dev/null) || continue

        printf '%s\n%s\n' "$index" "$result" >>"$cache"
        log debug "$result"
        echo "$result"
        return 0
    done
    die 1 $'no valid items in the chain:\n'"$chain"
}

cleanup() {
    if [[ -n "$tmpdir" && -d "$tmpdir" ]]; then
        rm -fR "$tmpdir"
    fi
}

declare -x tmpdir
tmpdir=$(mktemp -d)

# shellcheck disable=SC2034
declare -g callchain command_context_identifier="command"
declare -x pipe=$tmpdir/pipe
declare -g cache="$tmpdir/cache"

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

touch "$cache"
mkfifo "$pipe"
trap cleanup EXIT
