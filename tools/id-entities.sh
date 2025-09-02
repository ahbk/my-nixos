#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2030,SC2031,SC2016
#
# SC2317: This script has a dispatcher that makes dynamic calls to functions
# that shellcheck believes are unreachable, so we disable this check globally.
#
# SC2030/31: The exported variables (see below) are affected by dispatch calls
# with altered context (e.g. action=generate-public dispatch). This may be an
# anti-pattern, but it's not accidental, so we mute these warnings.
#
# SC2016: Yes, we know expressions wont expand in single quotes.

set -uo pipefail
shopt -s globstar
unset SOPS_AGE_KEY_FILE
declare -x SOPS_AGE_KEY_FILE mode entity action type

# import tmpdir, log, die, try and fn-exists
. ./tools/lib.sh

usage() {
    cat <<'EOF'
USAGE
    id-entities.sh [--host|--user|--domain|--root] <entity> <action> [type]
    id-entities.sh updatekeys
    id-entities.sh --help
EOF
}

usage-full() {
    less <<'EOF'
NAME
    id-entities.sh - Manage (id)entities like hosts, users or domains.

SYNOPSIS
    id-entities.sh [--root|--host|--user|--domain] <entity> <action> [type]
    id-entities.sh updatekeys
    id-entities.sh --help

DESCRIPTION
    This script provides a unified interface for managing the state and
    whereabouts of secrets and artifacts derived from secrets.
    It automates creation, synchronization, and audition of keys within an
    infrastructure.

MODES
   The first argument determines the operational mode, specifying the type of
   entity to manage.

   -r <root-id>     Manages root identities used to encrypt other entities.
   -h <host>        Manages secrets for a specific host.
   -u <user>        Manages secrets for a specific user.
   -d <domain>      Manages secrets for a domain, such as TLS certificates.

ACTIONS
    The action specifies the operation to perform on the entity:

    init             Create a new age identity and backend.
    new              See new-secret + sync.
    new-secret       Generate, encrypt and store a new secret.
    sync             Regenerate artifacts from secret.
    verify            Ensure consistency between the secret and artifacts.
    show             Write secret to stdout.
    show-public      Write public artifact to stdout.
    sideload         Push imperative secrets to host (age identity and luks).
    factory-reset    Wipe and re-install a host.

KEY TYPES
    The optional type argument specifies the kind of secret to manage.
    If not provided, it defaults to age-key.

    age-key   The primary key used for sops encryption.
    ssh-key   An SSH key (ed25519).
    wg-key    A WireGuard key.
    luks-key  A key for LUKS disk encryption.
    tls-cert  A TLS certificate for a domain.
    passwd    A user password.
    mail      A user's mail password.

COMMANDS
    updatekeys  Runs sops updatekeys across all managed secret files, re-encrypting
                them with the latest set of public keys defined in .sops.yaml.

ENVIRONMENT VARIABLES
    ROOT_KEY=<identity>
        Determines which root identity should be used for SOPS_AGE_KEY_FILE

    LOG_LEVEL=[debug|info|warning|error|important|focus|off]
        Sets logging verbosity

    SECRET_FILE=<path>
        If set during a `new`, `init` or `sideload` action, the contents of the
        specified file will be used as secret in lieu of generating a new.
EOF
}

main() {
    setup "$@" || die 1 "setup failed"

    dispatch
    local exit_code=$?

    case $exit_code in
    0) log success "$mode-$entity::$action::$type completed successfully" ;;
    *) log error "$mode-$entity::$action::$type completed with errors ($exit_code)" ;;
    esac
    exit "$exit_code"
}

setup() {
    case "${1-}" in
    -r | --root) mode="root" ;;
    -h | --host) mode="host" ;;
    -u | --user) mode="user" ;;
    -d | --domain) mode="domain" ;;
    *) mode=${1-} ;;
    esac

    case ${mode:-} in
    root | host | user | domain)
        [[ $# -eq 3 || $# -eq 4 ]] ||
            die 1 "wrong number of arguments provided." usage
        entity=$2
        action=$3
        type=${4-"age-key"}
        ;;
    updatekeys) ;;
    --help)
        usage-full
        exit 0
        ;;
    *)
        log error "hello! try --help"
        usage
        exit 1
        ;;
    esac

    [[ -f .sops.yaml ]] || try init-sops-yaml

    auth-check

    [[ $mode == updatekeys ]] && {
        updatekeys
        exit
    }

    backend-check
    keyadmin-check
    envvar-check
}

backend-check() {
    [[ $mode == "root" || $action == "init" || -f "$(backend-file)" ]] || {
        die 1 "'$(backend-file)' doesn't exist, did you spell $mode correctly?"
    }
}

auth-check() {
    SOPS_AGE_KEY_FILE=$(
        mode=root
        entity=$(root-key)
        yq-sops ".secrets.root"
    )

    authorize-key || die 1 "'$SOPS_AGE_KEY_FILE' is not root-$(root-key)"
}

keyadmin-check() {
    (
        LOG_LEVEL=off
        mode=user
        entity=$(key-admin)
        action=verify
        type=ssh-key
        get-secret >/dev/null
    ) || log warning "key admin '$(key-admin)' has no ssh-key, host checks wont work."
}

envvar-check() {
    [[ -z ${SECRET_FILE:-} || -r $SECRET_FILE ]] || die 1 "'$SECRET_FILE' is not a file"
}

authorize-key() {
    [[ "$mode-${entity-}" != "root-$(root-key)" ]] || return 0
    log debug "authorize-key"

    [[ -f $SOPS_AGE_KEY_FILE ]] || die 1 "no key file: '$SOPS_AGE_KEY_FILE'"

    local exit_code
    (
        mode=root
        entity=$(root-key)
        action=verify
        type=age-key
        verify-identity::age-key
    ) || die 1 "incorrect root key"
}

# Function dispatcher array - lists functions in priority order until one exists
# Pattern: most specific -> least specific -> fallback
#   1. mode::action::type  (e.g., "host::new::ssh-key")
#   2. mode::action        (e.g., "host::new")
#   3. action::type        (e.g., "new::ssh-key")
#   4. action              (e.g., "new")
dispatch() {
    dispatcher=(
        "$mode::$action::$type"
        "$mode::$action"
        "$action::$type"
        "$action"
    )
    for run in "${dispatcher[@]}"; do
        log debug "$run?"
        if fn-exists "$run"; then
            log info "$run!"
            "$run"
            return
        fi
    done
    die 127 "no function found for $mode::$action::$type"
}

# DISPATCHABLE FUNCTIONS START HERE

# --- *::init::*

init() {
    mkdir -p "$(dirname "$(backend-file)")"

    # Almost like new-secret but it writes directly to secret instead of set-secret
    # because set-secret expects a backend that doesn't exist yet.
    if [[ -n ${SECRET_FILE-} ]]; then
        try cat "$SECRET_FILE" >"$(secret)"
    else
        try age-keygen >"$(secret)"
    fi
    chmod 600 "$(secret)"

    action=validate dispatch || die 1 "verification failed"

    upsert-identity
    update-creation-rules

    init-backend
    flush-secret
}

root::init::age-key() {
    [[ ! -f $(backend-file) ]] || die 1 "root key '$(root-key)' already exists"
    new-secret
    upsert-identity
}

init-backend() {
    # shellcheck disable=SC2094
    # SC believes we're reading from $(backend-file) here, but --filename-override
    # simply tells sops what creation rule to use, so this is ok.
    echo "init: true" | try sops encrypt \
        --filename-override "$(backend-file)" \
        /dev/stdin >"$(backend-file)" || die 1 "could not create $(backend-file)"
}

# --- *::new::*

new() {
    new-secret
    action=sync dispatch
}

root::new::age-key() {
    [[ "$entity" != "$(root-key)" ]] || die 1 "can't rotate current root key"
    new-secret
    upsert-identity
}

host::new::ssh-key() {
    new-secret
    set-public
    log warning "public ssh keys will be overwritten by host's ssh keys on sync"
}

host::new::luks-key() {
    new-secret
}

# --- *::new-secret::*

new-secret() {
    if [[ -n ${SECRET_FILE:-} ]]; then
        action=set-secret dispatch <"$SECRET_FILE"
    else
        action=create-private dispatch | action=set-secret dispatch
    fi
}

# --- *::sync::*

sync() {
    set-public >/dev/null
}

sync::age-key() {
    gen-public | upsert-identity
}

host::sync::ssh-key() {
    host::pull::ssh-key >"$(public-file)"
}

user::sync::passwd() {
    sync-hash
}

user::sync::mail() {
    sync-hash
}

sync-hash() {
    local hash
    hash=$(mkpasswd -sm sha-512 <"$(get-secret)")
    (
        type=$type-hashed
        echo "$hash" | set-secret
    ) || die 1 "could not sync '$type-hashed'"
}

# --- *::verify::*

verify() {
    verify-public
}

verify::age-key() {
    verify-identity::age-key
}

host::verify::age-key() {
    verify-identity::age-key
    verify-host::age-key
}

host::verify::ssh-key() {
    host::pull::ssh-key | try diff - "$(get-public)" >&2 || die 1 "not same"
}

host::verify::luks-key() {
    try ssh "$(key-admin)@$(fqdn)" luks-key <"$(get-secret)"
}

user::verify::passwd() {
    verify-hash
}

user::verify::mail() {
    verify-hash
}

domain::verify::tls-cert() {
    local exit_code=0 san key cert public_file
    public_file=$(get-public)

    if ! openssl x509 -in "$public_file" -checkend 2592000 >/dev/null 2>&1; then
        log warning "Certificate expires within 30 days"
        exit_code=1
    fi

    san=$(openssl x509 -in "$public_file" -noout -ext subjectAltName 2>/dev/null |
        grep -E "DNS:" | sed 's/.*DNS://g' | tr ',' '\n' | sort)

    if [[ "$san" != *"$entity"* ]]; then
        log warning "Domain $entity not found in SAN: $san"
        exit_code=1
    fi

    key=$(openssl pkey -in "$(get-secret)" -pubout)
    cert=$(openssl x509 -in "$public_file" -pubkey -noout)

    if [[ "$key" != "$cert" ]]; then
        log error "Public key mismatch between certificate and private key"
        exit_code=1
    fi

    log info "Certificate public key: $(echo "$cert" | sed -n '2p')"

    return "$exit_code"
}

# --- *::verify-[public|identity|host|hash]::*

verify-public() {
    (try diff "$(gen-public)" "$(get-public)") || die 1 "not same"
}

verify-identity::age-key() {
    get-identity | try diff "$(gen-public)" - || die 1 "not same"
}

verify-host::age-key() {
    tail -1 "$(get-secret)" |
        try ssh "$(key-admin)@$(fqdn)" age-key |
        log info ||
        die 1 "not same"
}

verify-hash() {
    local salt
    salt=$(
        type=$type-hashed
        awk -F'$' '{print $3}' "$(get-secret)"
    )

    mkpasswd -sm sha-512 -S "$salt" <"$(get-secret)" |
        try diff - "$(type=$type-hashed get-secret)" || die 1 "not same"
}

# --- *::pull::*

host::pull::ssh-key() {
    try ssh-keyscan -q "$(fqdn)" | awk '{print $2, $3}' ||
        die 1 "scan failed"
}

# --- *::sideload::*

sideload() {
    local current_key
    current_key=$(mktemp "$tmpdir/XXXXXX")

    cat "$(get-secret)" >"$current_key"

    action=new dispatch

    {
        tail -1 "$current_key"
        tail -1 "$(get-secret)"
    } | try ssh "$(key-admin)@$(fqdn)" "$type" || die 1 "sideload failed"

    log warning "rebuild '$entity' now or suffer the consequences"
}

host::sideload::age-key() {
    (action=verify-identity dispatch) ||
        die 1 "keys are not in sync, run '$0 -h $entity sync age-key' first"

    sideload
}

# --- *::factory-reset::*

host::factory-reset() {
    local extra_files="$tmpdir/extra-files"
    local luks_key="$tmpdir/luks_key"
    local age_key="$extra_files/keys/host-$entity"

    install -d -m700 "$(dirname "$age_key")"

    cp "$(type=luks-key get-secret)" "$luks_key"
    cp "$(type=age-key get-secret)" "$age_key"

    chmod 600 "$age_key"

    log info "luks key prepared: $(cat "$luks_key")"
    log info "age key prepared: $(cat "$age_key")"

    nixos-anywhere \
        --flake ".#$entity" \
        --target-host "root@$(fqdn)" \
        --ssh-option GlobalKnownHostsFile=/dev/null \
        --disk-encryption-keys /luks-key "$luks_key" \
        --generate-hardware-config nixos-facter hosts/"$entity"/facter.json \
        --extra-files "$extra_files" \
        --copy-host-keys
}

# --- *::create-private::*

create-private::age-key() {
    try age-keygen | tail -1
}

create-private::ssh-key() {
    local tmpkey
    tmpkey=$(mktemp -u "$tmpdir/XXXXXX")
    try ssh-keygen -q -t "ed25519" -f "$tmpkey" -N "" -C "" <<<y 2>/dev/null
    cat "$tmpkey"
}

create-private::wg-key() {
    try wg genkey
}

create-private::luks-key() {
    try gen-passwd
}

create-private::tls-cert() {
    try openssl genpkey -algorithm ED25519
}

create-private::passwd() {
    try gen-passwd
}

create-private::mail() {
    create-private::passwd
}
# --- *::generate-public::*

generate-public::age-key() {
    try age-keygen -y <"$(action=get-secret dispatch)"
}

generate-public::ssh-key() {
    try ssh-keygen -y -f "$(get-secret)"
}

generate-public::wg-key() {
    try wg pubkey <"$(get-secret)"
}

generate-public::tls-cert() {
    try openssl req -new -x509 -key "$(get-secret)" \
        -subj "/CN=*.$entity" \
        -addext "subjectAltName=DNS:*.$entity,DNS:$entity" \
        -nodes -out - -days 3650
}

# --- *::validate::*

validate() {
    gen-public >/dev/null
}

validate::luks-key() {
    validate-passphrase
}

validate::passwd() {
    validate-passphrase
}

validate::mail() {
    validate-passphrase
}

validate::passwd-hashed() {
    validate-hash
}

validate::mail-hashed() {
    validate-hash
}

validate-hash() {
    [[ "$(<"$(get-secret)")" =~ ^\$6\$[^$]+\$[./0-9A-Za-z]+$ ]]
}

validate-passphrase() {
    head -n1 "$(get-secret)" | grep -qE '^.{12,}$'
}

# --- *::show::*

show() {
    echo "$(<"$(get-secret)")"
}

# --- *::show-public::*

show-public() {
    echo "$(<"$(get-public)")"
}

# --- sops integrations

init-sops-yaml() {
    [[ -f .sops.yaml ]] &&
        die 1 "will not overwrite existing .sops.yaml"

    cat >.sops.yaml <<'EOF'
dns-suffix: .local
key-admin: keyservice

secrets:
    root: keys/root-$entity
    host: hosts/$entity/secrets.yaml
    user: users/$entity-enc.yaml
    domain: domains/$entity-enc.yaml

public-file:
    host: hosts/$entity/$type.$pubext
    user: users/$entity-$type.$pubext
    domain: domains/$entity-$type.$pubext
EOF
}

yq-sops() {
    [[ -f .sops.yaml ]] || die 1 ".sops.yaml doesn't exist"
    local query

    query=$(echo "$1" | envsubst)
    if [[ ${2-} == "-i" ]]; then
        try yq -i "$query" .sops.yaml || die 1 "could not get $query"
    else
        try yq -e "$query" .sops.yaml | envsubst
    fi
}

get-identity() {
    yq-sops '.identities.$mode-$entity // error("identity $mode-$entity not found in .sops.yaml")'
}

upsert-identity() {
    local query='with(.identities.$mode-$entity; . = "$age_key" | . anchor = "$mode-$entity")'
    age_key=$(gen-public-key) yq-sops "$query" -i
    updatekeys
}

update-creation-rules() {
    local query='
    (
        del(.creation_rules[] | select(.auto == true)) |
        . as $d |
        $d.identities | keys | map(select(. == "root-*")) as $roots |
        $d.identities | keys | map(select(. != "root-*")) |
            map({
                "auto": true,
                "path_regex": split("-") as $a | $d.secrets[$a[0]] | sub("\\$entity"; $a[1]),
                "key_groups": [{
                    "age": $roots + [.] | map(. as $_ | . alias = .)
                }]
        })
    ) as $generated_rules
    | .creation_rules += $generated_rules'

    try yq -i "$query" .sops.yaml
}

updatekeys() {
    update-creation-rules

    local _mode files

    for _mode in user host domain; do
        glob="$(entity="*" yq-sops ".secrets.$_mode" .sops.yaml)"

        eval "files=($glob)"
        [[ "${files[0]}" != "$glob" ]] || return 0

        sops updatekeys -y "${files[@]}" > >(log important) 2> >(grep 'synced with' | log info)
    done

    log success "backend updated"
}

# --- derived variables

fqdn() {
    echo "$entity$(yq-sops ".dns-suffix")"
}

key-admin() {
    yq-sops ".key-admin"
}

root-key() {
    echo "${ROOT_KEY:-1}"
}

secret() {
    echo "$tmpdir/$mode.$entity.$type.secret"
}

get-secret() {
    [[ -f $(secret) ]] || {
        try sops decrypt --extract "$(backend-path)" "$(backend-file)" >"$(secret)"
        chmod 600 "$(secret)"
    }
    secret
}

set-secret() {
    cat >"$(secret)"
    chmod 600 "$(secret)"

    action=validate dispatch || die 1 "verification failed"
    flush-secret
}

flush-secret() {
    try sops set "$(backend-file)" "$(backend-path)" "$(jq -Rs <"$(secret)")"
}

root::get-secret() {
    [[ -f $(secret) ]] || root::set-secret <"$(backend-file)"
    secret
}

root::set-secret() {
    cat >"$(secret)"
    chmod 600 "$(secret)"
    action=validate dispatch || die 1 "verification failed"
    cp -a "$(secret)" "$(backend-file)"
}

get-public() {
    local public_file
    public_file=$(public-file)
    [[ -f $public_file ]] || die 1 "public file doesn't exist"
    echo "$public_file"
}

gen-public-key() {
    action=generate-public dispatch
}

gen-public() {
    local public_file="$tmpdir/$mode.$entity.$type.public"
    [[ -f $public_file ]] || gen-public-key >"$public_file"
    echo "$public_file"
}

set-public() {
    local public_file
    public_file=$(public-file)
    gen-public-key >"$public_file"
    echo "$public_file"
}

public-file() {
    local pubext
    case $type in
    tls-cert) pubext="pem" ;;
    ssh-key) pubext="pub" ;;
    wg-key) pubext="pub" ;;
    *) die 1 "no public file for this type" ;;
    esac
    pubext=$pubext yq-sops ".public-file.$mode"
}

backend-file() {
    yq-sops ".secrets.$mode"
}

backend-path() {
    path="['$type']"
    [[ $mode != host ]] && path="['$entity']$path"
    echo "$path"
}

# --- misc helpers

gen-passwd() {
    try openssl rand -base64 12
}

# --- main
main "$@"
