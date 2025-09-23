#!/usr/bin/env bash
# as.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/run-with.bash"

cleanup() {
    ssh-agent -k >/dev/null
}
trap cleanup EXIT

as() {
    local entity=$1
    local key_file=$tmpdir/age-key
    shift

    eval "$(ssh-agent -s)" >/dev/null 2> >(log info)

    "$here/id-entities.sh" "$entity" cat-secret age-key >"$key_file"

    SOPS_AGE_KEY_FILE=$key_file "$here/id-entities.sh" "$entity" cat-secret ssh-key |
        ssh-add - 2> >(log info)

    SOPS_AGE_KEY_FILE=$key_file "$@"
}

as "$@"
