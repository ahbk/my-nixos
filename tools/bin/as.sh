#!/usr/bin/env bash
# as.sh

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"

cleanup() {
    ssh-agent -k > >(log info)
}
trap cleanup EXIT

as() {
    local entity=$1
    local key_file=$tmpdir/age-key
    shift

    eval "$(ssh-agent -s)" > >(log info)

    "$km_root/bin/id-entities.sh" "$entity" cat-secret age-key >"$key_file"

    SOPS_AGE_KEY_FILE=$key_file "$km_root/bin/id-entities.sh" "$entity" cat-secret ssh-key |
        ssh-add - 2> >(log info)

    SOPS_AGE_KEY_FILE=$key_file "$@"
}

as "$@"
