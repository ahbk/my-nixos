#!/usr/bin/env bash

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$root/lib.sh"

cleanup() {
    ssh-agent -k >/dev/null
}
trap cleanup EXIT

main() {
    export LOG_LEVEL=error
    local entity=$1
    local key_file=$tmpdir/age-key
    shift
    eval "$(ssh-agent -s)" >/dev/null
    "$root/id-entities.sh" "$entity" cat-secret age-key >"$key_file"
    "$root/id-entities.sh" "$entity" cat-secret ssh-key | ssh-add -
    SOPS_AGE_KEY_FILE=$key_file "$@"
}

main "$@"
