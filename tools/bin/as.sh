#!/usr/bin/env bash
# tools/bin/as.sh

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"

cleanup() {
    ssh-agent -k > >(log info)
}
trap cleanup EXIT

as() {
    local identity
    identity=$(org-toml.sh "autocomplete-identity" "$1")
    mkdir -p "$tmpdir/keys"
    local key_file=$tmpdir/keys/$identity
    shift

    eval "$(ssh-agent -s)" > >(log info)

    "$km_root/bin/id-entities.sh" "$identity" cat-secret age-key >"$key_file"

    SOPS_AGE_KEY_FILE=$key_file "$km_root/bin/id-entities.sh" "$identity" cat-secret ssh-key |
        ssh-add - 2> >(log info)

    SOPS_AGE_KEY_FILE=$key_file "$@"
}

as "$@"
