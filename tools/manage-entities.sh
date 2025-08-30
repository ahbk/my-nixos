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
declare -x SOPS_AGE_KEY_FILE root_key mode entity action type
root_key=${ROOT_KEY:-1}

# import tmpdir, log, die, try and fn-exists
. ./tools/lib.sh

usage() {
    cat <<'EOF'
USAGE
    ./manage-entities.sh [-h|-u|-d|-r] entity action [type]
    ./manage-entities.sh updatekeys
    ./manage-entities.sh --help
EOF
}

usage-full() {
    less <<'EOF'
NAME
    ./manage-entities.sh - Manage sops-encrypted secrets for hosts, users, and domains.

SYNOPSIS
    ./manage-entities.sh [-h|-u|-d|-r] entity action [type]
    ./manage-entities.sh updatekeys
    ./manage-entities.sh --help

DESCRIPTION
    This script provides a unified interface for managing cryptographic keys and
    secrets using sops and age. It simplifies creating, synchronizing, and
    auditing keys for different entities within a system.

MODES
   The first argument determines the operational mode, specifying the type of
   entity to manage.

   -r <root-id>     The root age key(s), which is used to encrypt other keys.
   -h <host>        Manages secrets for a specific host.
   -u <user>        Manages secrets for a specific user.
   -d <domain>      Manages secrets for a domain, such as TLS certificates.

ACTIONS
    The action specifies the operation to perform on the entity.

    new       Generates a new private key, encrypts it with sops, and derives
              the corresponding public key.

    sync      Decrypts the private key, regenerates the public key, and updates
              the .sops.yaml anchor if applicable. This ensures public and
              private keys are synchronized.

    check     Performs a check to ensure consistency between the private key,
              the public key, the sops anchor, and the key deployed on a remote
              target (if applicable).

    init      Initializes a new entity by creating its configuration in
              .sops.yaml, generating a new age key, and creating an initial
              encrypted secrets file.

    pull      (Host-specific) Fetches the public SSH key from a remote host and
              saves it.

    sideload  (Host-specific) Injects a new age key into a host's
              /etc/age/keys.txt file. Requires a subsequent host rebuild.

    factory-  (Host-specific) Re-installs a NixOS host using nixos-anywhere,
    reset     injecting LUKS and age keys during the installation.

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
    LOG_LEVEL=[debug|info|warning|error]
        Sets logging verbosity

    PRIVATE_FILE=<path>
        If set during a `new` action, the script will use the contents of the
        specified file as the private key instead of generating a new.

CONFIGURATION: .sops.yaml
    The script parses .sops.yaml to understand the repository's structure and
    encryption rules. Example configuration:

    keys:
      - &root-1 [age...]

    key-file: ./keys.txt
    key-host-file: /etc/age/keys.txt
    dns-suffix: .local
    key-admin: keyservice

    secrets:
        host: hosts/$entity/secrets.yaml
        user: users/$entity-enc.yaml
        domain: domains/$entity-enc.yaml

    public-file:
        host: hosts/$entity/$type
        user: users/$entity-$type
        domain: domains/$entity-$type

EXAMPLES

Create first root key:
./manage-entities.sh -r 1 new

Initialize a new host named server1:
./manage-entities.sh -h server1 init

Check if the age key for server1 is synchronized everywhere:
./manage-entities.sh -h server1 check age-key

Create a new password for user alice:
./manage-entities.sh -u alice new passwd

Update all secrets after changing an age key:
./manage-entities.sh updatekeys
EOF
}

main() {
    setup "$@" || die 1 "setup failed"

    dispatch
    local exit_code=$?

    case $exit_code in
    0) log "$mode-$entity::$action::$type completed successfully" success ;;
    *) log "$mode-$entity::$action::$type completed with errors ($exit_code)" error ;;
    esac
    exit "$exit_code"
}

setup() {
    case "${1-}" in
    -r | --root) mode="root" ;;
    -h | --host) mode="host" ;;
    -u | --user) mode="user" ;;
    -d | --domain) mode="domain" ;;
    --help) mode="help" ;;
    updatekeys) mode="updatekeys" ;;
    *) die 1 "hello! try --help" usage ;;
    esac

    case $mode in
    root | host | user | domain)
        [[ $# -eq 3 || $# -eq 4 ]] ||
            die 1 "wrong number of arguments provided." usage
        entity=$2
        action=$3
        type=${4-"age-key"}
        ;;
    help)
        usage-full
        exit 0
        ;;
    updatekeys)
        updatekeys
        exit 0
        ;;
    esac

    local types
    local actions=(
        new
        new-private
        sync
        check
    )

    [[ $type == "age-key" ]] && actions+=(
        check-anchor
        sync-anchor
        init
    )

    case $mode in
    root)
        type=age-key
        types=(age-key)
        actions=(init new check)
        ;;
    host)
        types=(age-key ssh-key wg-key luks-key)

        [[ $type == "age-key" ]] && actions+=(
            sideload
            factory-reset
        )
        ;;
    user)
        types=(age-key ssh-key passwd mail)
        ;;
    domain)
        types=(age-key tls-cert)
        ;;
    esac

    [[ -f .sops.yaml ]] || try init-sops-yaml
    SOPS_AGE_KEY_FILE=$(entity=$root_key yq-sops ".secrets.root")

    [[ -z ${PRIVATE_FILE:-} || -r $PRIVATE_FILE ]] || die 1 "$PRIVATE_FILE is not a file"

    (
        LOG_LEVEL=off
        mode=user
        entity=$(key-admin)
        type=ssh-key
        get-secret >/dev/null
    ) || log "user '$(key-admin)' doesn't have an ssh key, host checks wont work." warning

    authorize-key || die 1 "authorization failed"

    # shellcheck disable=SC2076
    [[ " ${actions[*]} " =~ " $action " ]] ||
        die 1 "Action '$action' is not for '$mode'+'$type'."$'\n'"Allowed actions are: ${actions[*]}" usage

    # shellcheck disable=SC2076
    [[ " ${types[*]} " =~ " $type " ]] ||
        die 1 "'$type' is not a valid key type. Allowed key types: ${types[*]}" usage

    [[ $mode == "root" || $action == "init" || -f "$(secrets-file)" ]] || {
        die 1 "no file found in '$(secrets-file)', did you spell $mode correctly?"
    }
}

authorize-key() {
    [[ "$mode-$entity" != "root-$root_key" ]] || return 0
    log "authorize-key" debug

    [[ -f $SOPS_AGE_KEY_FILE ]] || die 1 "no key file: $SOPS_AGE_KEY_FILE"

    local exit_code
    (
        mode=root
        action=check
        type=age-key
        entity=$root_key
        check-anchor::age-key
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
        log "$run?" debug
        if fn-exists "$run"; then
            log "$run!" info
            "$run"
            return
        fi
    done
    die 127 "no function found for $mode::$action::$type"
}

# DISPATCHABLE FUNCTIONS START HERE
# Helpers suffixed with --*

# --- *::new::*
# See new-private + sync

new() {
    new-private
    action=sync dispatch
}

# --- *::new-private::*
# Generate/copy a private resource then validate and encrypt it

new-private() {
    if [[ -n ${PRIVATE_FILE:-} ]]; then
        action=set-secret dispatch <"$PRIVATE_FILE"
    else
        action=create-private dispatch | action=set-secret dispatch
    fi
}

root::init::age-key() {
    [[ ! -f $(secrets-file) ]] || die 1 "root key $root_key already exists"
    new-private
    upsert-anchor
}

root::new::age-key() {
    [[ "$entity" != "$root_key" ]] || die 1 "can't rotate current root key"
    new-private
    upsert-anchor
}

host::new::ssh-key() {
    new-private
    set-public
    log "public ssh keys will be overwritten by host's ssh keys on sync" warning
}

# --- *::sync::*
# Decrypt a private resource and use it to generate and save/replace a public key

sync() {
    set-public
}

sync::age-key() {
    gen-public | upsert-anchor && updatekeys
}

host::sync::ssh-key() {
    host::pull::ssh-key >"$(public-file)"
}

sync::luks-key() {
    log "luks-key sync not implemented yet" warning
}

# Linux passwords are famously hashed so we need to encrypt both plain and
# hashed format and keep them in sync.
user::sync::passwd() {
    local hash
    hash=$(mkpasswd -sm sha-512 <"$(get-secret)")
    (
        type=$type-hashed
        echo "$hash" | set-secret
    )
}

# nixos-mailserver uses linux-like password management
user::sync::mail() {
    user::sync::passwd
}

# --- *::check::*

host::check::age-key() {
    check-anchor::age-key && check-host::age-key
}

host::check::ssh-key() {
    local file host

    log "check ssh-keyscan against public file" info

    host=$(host::pull::ssh-key | try ssh-keygen -lf -) || die 1 "keyscan failed"
    file=$(try ssh-keygen -lf "$(get-public)") || die 1 "failed to read $(public-file)"

    diff <(echo "$host") <(echo "$file")
}

host::check::wg-key() {
    check-public
}

host::check::luks-key() {
    local cmd='sudo cryptsetup open --test-passphrase --key-file=- /dev/sda3'
    try ssh "$(key-admin)@$(fqdn)" "$cmd" <"$(get-secret)"
}

check::age-key() {
    check-anchor::age-key
}

user::check::ssh-key() {
    check-public
}

user::check::passwd() {
    local salt hash
    salt=$(
        type=$type-hashed
        awk -F'$' '{print $3}' "$(get-secret)"
    )

    hash=$(mkpasswd -sm sha-512 -S "$salt" <"$(get-secret)")
    echo "$hash" | diff - "$(type=$type-hashed get-secret)"
}

user::check::mail() {
    user::check::passwd
}

domain::check::tls-cert() {
    local exit_code=0 san key cert public_file
    public_file=$(get-public)

    if ! openssl x509 -in "$public_file" -checkend 2592000 >/dev/null 2>&1; then
        log "Certificate expires within 30 days" warning
        exit_code=1
    fi

    san=$(openssl x509 -in "$public_file" -noout -ext subjectAltName 2>/dev/null |
        grep -E "DNS:" | sed 's/.*DNS://g' | tr ',' '\n' | sort)

    if [[ "$san" != *"$entity"* ]]; then
        log "Domain $entity not found in SAN: $san" warning
        exit_code=1
    fi

    key=$(openssl pkey -in "$(get-secret)" -pubout)
    cert=$(openssl x509 -in "$public_file" -pubkey -noout)

    if [[ "$key" != "$cert" ]]; then
        log "Public key mismatch between certificate and private key" error
        exit_code=1
    fi

    log "Certificate public key: $(echo "$cert" | sed -n '2p')" info

    return "$exit_code"
}

check-public() {
    diff "$(gen-public)" "$(get-public)" || die 1 "check failed"
}

check-anchor::age-key() {
    grep -Fxq "$(get-anchor)" "$(gen-public)"
}

check-host::age-key() {
    grep -Fxq "$(action=pull dispatch)" "$(gen-public)"
}

# --- *::pull::*

host::pull::age-key() {
    log "cat $(host-key-file) on $(fqdn)" info
    try ssh "$(key-admin)@$(fqdn)" "cat $(host-key-file)" | set-secret ||
        die 1 "failed to retreive key from host"

    gen-public-key
}

host::pull::ssh-key() {
    log "ssh-keyscan $(fqdn)" info
    try ssh-keyscan -q "$(fqdn)" || die 1 "scan failed"
}

# --- *::sideload::*

host::sideload::age-key() {
    check-anchor::age-key ||
        die 1 "Error: Keys are out of sync, run '$0 $entity sync age-key' first"

    check-host::age-key &&
        die 1 "current key is already active"

    try ssh "$(key-admin)@$(fqdn)" "head -n 3 $(host-key-file)" | set-secret
    try scp "$(get-secret)" "$(key-admin)@$(fqdn):$(host-key-file)" >/dev/null
    log "rebuild host '$entity' now or suffer the consequences" warning
}

# --- *::factory-reset::*

host::factory-reset() {
    local extra_files="$tmpdir/extra-files"
    local luks_key="$tmpdir/luks_key"
    local decryption_keys="$extra_files/srv/storage/host/keys.txt"

    install -d -m700 "$(dirname "$decryption_keys")"

    type=luks-key cp "$(get-secret)" "$luks_key"
    type=age-key cp "$(get-secret)" "$decryption_keys"

    chmod 600 "$decryption_keys"

    log "luks key prepared: $(cat "$luks_key")" info
    log "decryption keys prepared: $(sed -n '3p' "$decryption_keys")" info

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
    try age-keygen
}

create-private::ssh-key() {
    try ssh-keygen -q -t "ed25519" -f "$tmpdir/tmp-ssh-key" -N "" \
        -C "$mode-key-$(date +%Y-%m-%d)" <<<y 2>/dev/null
    cat "$tmpdir/tmp-ssh-key"
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

# --- *::verify::*

verify() {
    gen-public >/dev/null
}

verify::luks-key() {
    log "luks-key verification not implemented yet" warning
}

verify::mail() {
    verify::passwd
}

verify::passwd() {
    head -n1 "$(get-secret)" | grep -qE '^.{12,}$'
}

verify::mail-hashed() {
    verify::passwd-hashed
}

verify::passwd-hashed() {
    [[ "$(<"$(get-secret)")" =~ ^\$6\$[^$]+\$[./0-9A-Za-z]+$ ]]
}

# --- *::init::*

init() {
    mkdir -p "$(dirname "$(secrets-file)")"

    if [[ -n ${PRIVATE_FILE-} ]]; then
        try cat "$PRIVATE_FILE" >"$(secret)"
    else
        try age-keygen >"$(secret)"
    fi
    chmod 600 "$(secret)"
    action=verify dispatch || die 1 "verification failed"

    upsert-anchor
    update-creation-rules

    # shellcheck disable=SC2094
    # SC believes we're reading from $(secrets-file) here but --filename-override
    # simply tells sops what creation rule to use.
    echo "init: true" | try sops encrypt \
        --filename-override "$(secrets-file)" \
        /dev/stdin >"$(secrets-file)" || die 1 "could not create $(secrets-file)"

    try sops set "$(secrets-file)" "$(secrets-path)" "$(jq -Rs <"$(secret)")"
}

# --- sops integrations

get-anchor() {
    yq-sops '.entities.$mode-$entity // error("Anchor $mode-$entity not found in .sops.yaml")'
}

upsert-anchor() {
    local query='with(.entities.$mode-$entity; . = "$age_key" | . anchor = "$mode-$entity")'
    age_key=$(gen-public-key) yq-sops "$query" -i
    updatekeys
}

update-creation-rules() {
    local query='
    (
        del(.creation_rules[] | select(.auto == true)) |
        . as $d |
        $d.entities | keys | map(select(. == "root-*")) as $roots |
        $d.entities | keys | map(select(. != "root-*")) |
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

    local _mode
    for _mode in user host domain; do

        files=$(secrets-glob "$_mode")

        [[ -z "${files[*]}" ]] && {
            log "no secrets in $_mode: skipping" info
            continue
        }

        log "<$_mode>" info
        # shellcheck disable=SC2068
        sops updatekeys -y ${files[@]}
        log "</$_mode>" info
    done
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

init-sops-yaml() {
    [[ -f .sops.yaml ]] &&
        die 1 "will not overwrite existing .sops.yaml"

    cat >.sops.yaml <<'EOF'
host-key-file: /etc/age/keys.txt
dns-suffix: .local
key-admin: keyservice

secrets:
    root: keys/$entity
    host: hosts/$entity/secrets.yaml
    user: users/$entity-enc.yaml
    domain: domains/$entity-enc.yaml

public-file:
    host: hosts/$entity/$type.$pubext
    user: users/$entity-$type.$pubext
    domain: domains/$entity-$type.$pubext
EOF
}

# --- derived variables

secret() {
    echo "$tmpdir/$mode.$entity.$type.secret"
}

root::get-secret() {
    [[ -f $(secret) ]] || root::set-secret <"$(secrets-file)"
    secret
}

get-secret() {
    [[ -f $(secret) ]] ||
        try sops decrypt --extract "$(secrets-path)" "$(secrets-file)" | set-secret
    secret
}

root::set-secret() {
    cat >"$(secret)"
    chmod 600 "$(secret)"
    action=verify dispatch || die 1 "verification failed"
    cp -a "$(secret)" "$(secrets-file)"
}

set-secret() {
    cat >"$(secret)"
    chmod 600 "$(secret)"

    action=verify dispatch || die 1 "verification failed"
    try sops set "$(secrets-file)" "$(secrets-path)" "$(jq -Rs <"$(secret)")"
}

fqdn() {
    echo "$entity$(yq-sops ".dns-suffix")"
}

host-key-file() {
    yq-sops ".host-key-file"
}

key-admin() {
    yq-sops ".key-admin"
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

secrets-file() {
    yq-sops ".secrets.$mode"
}

secrets-path() {
    path="['$type']"
    [[ $mode != host ]] && path="['$entity']$path"
    echo "$path"
}

# --- misc helpers

secrets-glob() {
    local _mode=$1
    glob="$(entity="*" yq-sops ".secrets.$_mode" .sops.yaml)"

    eval "files=($glob)"

    [[ "${files[0]}" != "$glob" ]] || return 0

    echo "${files[@]}"
}

gen-passwd() {
    try openssl rand -base64 12
}

# --- main
main "$@"
