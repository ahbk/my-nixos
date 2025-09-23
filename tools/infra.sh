#!/usr/bin/env bash
# infra.sh
# shellcheck disable=SC2317,SC2030,SC2031,SC2016
# SC2016: Yes, we know expressions wont expand in single quotes.

set -uo pipefail

declare -x session class entity action key

declare -x here
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$here/sops-yaml.sh"
. "$here/run-with.bash"

for-all-identities() {
    all-identities | while IFS="-" read -r class entity; do

        get-ops "$1" 2>/dev/null | while IFS= read -r ak; do
            if [[ $ak == *" "* ]]; then
                IFS=' ' read -r prefix key <<<"$ak"
            else
                IFS=':' read -r prefix key <<<"$ak"
            fi
            LOG_LEVEL=success ./tools/id-entities.sh --"$class" "$entity" "$prefix" "$key"

        done
    done
}

for-all-identities "$@"
