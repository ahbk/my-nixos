#!/usr/bin/env bash

set -uo pipefail
unset SOPS_AGE_KEY_FILE

# import tmpdir, log, die, try and fn-exists
. ./tools/lib.sh

# Count total operations
total=$(yq eval '.identities | keys | length' .sops.yaml)
current=0

declare -A manifest=(
    [host]="wg-key"
    [host_helsinki]="age-key luks-key ssh-key wg-key"
    [host_lenovo]="age-key ssh-key wg-key"
    [user]="age-key ssh-key passwd mail"
    [user_keyservice]="age-key ssh-key"
    [domain]="age-key tls-cert"
    [root]="age-key"
)

main() {
    bulk-action verify
}

bulk-action() {
    local types action=$1

    yq eval '.identities | keys | .[]' .sops.yaml | while IFS='-' read -r mode entity; do

        ((current++))

        log info "[$current/$total] Processing $mode-$entity"

        types=${manifest[${mode}_${entity}]:-${manifest[$mode]:-}}

        for type in $types; do
            LOG_LEVEL=warning ./tools/id-entities.sh --"$mode" "$entity" "$action" "$type"
        done
    done
}

main "$@"
