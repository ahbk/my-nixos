#!/usr/bin/env bash

set -uo pipefail
unset SOPS_AGE_KEY_FILE

# import tmpdir, log, die, try and fn-exists
. ./tools/lib.sh

# Count total operations
total=$(yq eval '.entities | keys | length' .sops.yaml)
current=0

declare -A types=(
    [host]="wg-key"
    [user]="passwd mail"
    [domain]="tls-cert"
    [root]="age-key"
)

main() {
    bulk-action "$1"
}

bulk-action() {
    local action=$1
    yq eval '.entities | keys | .[]' .sops.yaml | while IFS='-' read -r mode entity; do
        ((current++))
        log "[$current/$total] Processing $mode-$entity" info
        for type in ${types[$mode]:-}; do
            LOG_LEVEL=warning ./tools/manage.sh --"$mode" "$entity" "$action" "$type"
        done
    done
}

main "$@"
