#!/usr/bin/env bash
# infra.sh

set -uo pipefail

declare -x session class entity action key

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"
# shellcheck source=../libexec/sops-yaml.sh
. "$km_root/libexec/sops-yaml.sh"

for-all-identities() {
    all-identities | while IFS="-" read -r class entity; do
        [[ "$class" != "root" ]] || continue

        get-ops "$1" 2>/dev/null | while IFS= read -r ak; do
            if [[ $ak == *" "* ]]; then
                IFS=' ' read -r prefix key <<<"$ak"
            else
                IFS=':' read -r prefix key <<<"$ak"
            fi
            "$km_root/bin/id-entities.sh" --"$class" "$entity" "$prefix" "$key"

        done
    done
}

for-all-identities "$@"
