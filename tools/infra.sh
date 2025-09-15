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
    for-all-identities "$1"
}

for-all-identities() {
    local ak aks

    yq eval '.identities | keys | .[]' .sops.yaml | while IFS='-' read -r class entity; do

        aks=$(LOG_LEVEL=off op=$1 yq-sops-e '.ops.$op
        | with_entries(select(
            .key == "$class-$entity" or
            .key == "$class" or
            .key == "all"
            )
        ) | [.all[], .$class[], .$class-$entity[] ][]') || continue

        for ak in $aks; do
            IFS=':' read -r action key <<<"$ak"
            LOG_LEVEL=warning ./tools/id-entities.sh --"$class" "$entity" "$action" "$key"
        done
    done
}

main "$@"
