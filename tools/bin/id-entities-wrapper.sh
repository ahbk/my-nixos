#!/usr/bin/env bash
# id-entities-wrapper.sh
# shellcheck disable=all
# - just a draft

set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r here

# import run, with, log/try/die etc.
. "$here/run-with.bash"

# import upsert-identity, read-setting etc.
. "$here/sops-yaml.sh"

usage() {
    sed -n '/^USAGE$/,/^$/p' "$here/id-entities-usage.txt"
}

[[ -n ${1:-} ]] || die 1 "hello! try --help" usage

case "$1" in
-r | --root) class="root" ;;
-h | --host) class="host" ;;
-u | --user) class="user" ;;
-d | --domain) class="domain" ;;
-s | --service) class="service" ;;
-H | --help)
    less "$here/id-entities-usage.txt"
    exit 0
    ;;
*)
    if IFS= read -r class entity < <(autocomplete-identity "$1"); then
        shift
        set -- "$entity" "$@"
        set -- "$class" "$@"
    else
        die 1 "could not infer a valid context" usage
    fi
    ;;
esac

entity=${2:?"entity name required"}
prefix=${3:?"prefix is required"}
key=${4-"age-key"}
slot=${5:-0}

[[ "$prefix-$class-$entity" == "init-root-1" && ! -f ".sops.yaml" ]] && {
    log important "bootstrap conditions, creating .sops.yaml."
    create-sops-yaml
}

log info "prefix: $prefix"
log info "class: $class"
log info "entity: $entity"
log info "key: $key"
log info "slot: $slot"
declare -x class entity prefix key slot
"$here/id-entities-api.sh"
