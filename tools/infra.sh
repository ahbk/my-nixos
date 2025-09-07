#!/usr/bin/env bash
# infra.sh
# shellcheck disable=SC2317,SC2030,SC2031,SC2016
# SC2016: Yes, we know expressions wont expand in single quotes.

set -uo pipefail

declare -x session class entity action key

declare -x here
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib.sh"

main() {
    for action in $(op=$1 yq-sops '.ops.$op.actions[]'); do
        for-all-identities "$action"
    done
}

for-all-identities() {
    yq eval '.identities | keys | .[]' .sops.yaml | while IFS='-' read -r class entity; do
        LOG_LEVEL=warning ./tools/id-entities.sh --"$class" "$entity" "$action"
    done
}

main "$@"
