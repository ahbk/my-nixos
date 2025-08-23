#!/usr/bin/env bash
# shellcheck disable=SC2317,SC2030,SC2031,SC2016
#
# SC2317: This script has a dispatcher that makes dynamic calls to functions
# that shellcheck believes are unreachable, so we disable this check globally.
#
# SC2030/31: The exported variables (see below) are affected by dispatch calls
# with altered context (e.g. action=generate-public dispatch). This may be an
# anti- pattern, but it's not accidental, so we mute these warnings.
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

    reset     (Host-specific) Re-installs a NixOS host using nixos-anywhere,
              injecting LUKS and age keys during the installation.

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
    DEBUG=true
        Enables verbose logging, showing function calls and detailed steps.

    PRIVATE_FILE=<path>
        If set during a `new` action, the script will use the contents of the
        specified file as the private key instead of generating a new.

CONFIGURATION: .sops.yaml
    The script parses .sops.yaml to understand the repository's structure and
    encryption rules. Example configuration:

    keys:
      - &root-1 unset

    key-file: ./keys.txt
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

Create a new SSH key for server1:
./manage-entities.sh -h server1 new ssh-key

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
    0) log "$mode::$action::$type completed successfully" success ;;
    *) log "$mode::$action::$type completed with errors ($exit_code)" error ;;
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
        init
    )

    [[ $type == "age-key" ]] && actions+=(
        check-anchor
        sync-anchor
    )

    case $mode in
    root)
        type=age-key
        types=(age-key)
        ;;
    host)
        types=(age-key ssh-key wg-key luks-key)

        [[ $type == "ssh-key" ]] && actions+=(
            pull
            check-host
        )

        [[ $type == "age-key" ]] && actions+=(
            sideload
            factory-reset
            check-host
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
    SOPS_AGE_KEY_FILE=$(yq-sops ".key-file")
    set-key-admin
    authorize-key

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
    log "authorize-key" debug
    [[ "$mode-$entity" != "root-1" ]] || return 0
    [[ -f $SOPS_AGE_KEY_FILE ]] || die 1 "no key file: $SOPS_AGE_KEY_FILE"

    local exit_code
    (
        mode=root
        action=check
        type=age-key
        entity=1
        cat "$SOPS_AGE_KEY_FILE" >>"$(private-file)"
        check-anchor::age-key
    ) || die 1 "root key not authorized"
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
    action=new-private dispatch
    action=sync dispatch
}

# --- *::new-private::*
# Generate/copy a private resource then validate and encrypt it

new-private() {
    if [[ -n ${PRIVATE_FILE:-} ]]; then
        action=copy-private dispatch
    else
        action=create-private dispatch
    fi
    encrypt
}

root::new::age-key() {
    new-private
    generate-public::age-key | insert-anchor || die 1 "insert-anchor failed"
}

# --- *::sync::*
# Decrypt a private resource and use it to generate and save/replace a public key

sync() {
    decrypt
    action=generate-public dispatch >"$(public-file)"
}

sync::age-key() {
    decrypt
    sync-anchor::age-key
}

sync-anchor::age-key() {
    generate-public::age-key | upsert-anchor
    updatekeys
}

sync::luks-key() {
    return 0
}

# Linux passwords are famously hashed so we need to encrypt both plain and
# hashed format and keep them in sync.
user::sync::passwd() {
    decrypt
    local hash
    hash=$(mkpasswd -sm sha-512 <"$(private-file)")
    (
        type=$type-hashed
        echo "$hash" >"$(private-file)"
        encrypt
    )
}

# nixos-mailserver uses linux-like password management
user::sync::mail() {
    user::sync::passwd
}

# --- *::check::*

host::check::age-key() {
    local exit_code=0 ref
    decrypt

    ref="$(action=generate-public dispatch)"

    check-anchor::age-key "$ref" || exit_code=1
    check-host::age-key "$ref" || exit_code=1

    return "$exit_code"
}

host::check::ssh-key() {
    local exit_code=0 ref
    decrypt
    ref="$(action=generate-public dispatch)"

    check-public "$ref" || exit_code=1
    check-host::ssh-key "$ref" || exit_code=1

    return "$exit_code"
}

host::check::wg-key() {
    decrypt
    check-public
}

host::check::luks-key() {
    decrypt
    local cmd='sudo cryptsetup open --test-passphrase --key-file=- /dev/sda3'
    try ssh "$(key-admin)@$(fqdn)" "$cmd" <"$(private-file)"
}

check::age-key() {
    decrypt
    check-anchor::age-key "$(action=generate-public dispatch)"
}

user::check::ssh-key() {
    decrypt
    check-public
}

user::check::passwd() {
    local salt hash
    salt=$(
        type=$type-hashed
        decrypt
        awk -F'$' '{print $3}' "$(private-file)"
    )

    decrypt

    hash=$(mkpasswd -sm sha-512 -S "$salt" <"$(private-file)")
    echo "$hash" | diff - "$(type=$type-hashed private-file)"
}

user::check::mail() {
    user::check::passwd
}

domain::check::tls-cert() {
    local exit_code=0 san key cert

    decrypt

    if ! openssl x509 -in "$(public-file)" -checkend 2592000 >/dev/null 2>&1; then
        log "Certificate expires within 30 days" warning
        exit_code=1
    fi

    san=$(openssl x509 -in "$(public-file)" -noout -ext subjectAltName 2>/dev/null |
        grep -E "DNS:" | sed 's/.*DNS://g' | tr ',' '\n' | sort)

    if [[ "$san" != *"$entity"* ]]; then
        log "Domain $entity not found in SAN: $san" warning
        exit_code=1
    fi

    key=$(openssl pkey -in "$(private-file)" -pubout)
    cert=$(openssl x509 -in "$(public-file)" -pubkey -noout)

    if [[ "$key" != "$cert" ]]; then
        log "Public key mismatch between certificate and private key" error
        exit_code=1
    fi

    log "Certificate public key: $(echo "$cert" | sed -n '2p')" info

    return "$exit_code"
}

check-public() {
    local ref=${1-$(action=generate-public dispatch)}
    log "diff public file" info

    [[ -f $(public-file) ]] || die 1 "public key doesn't exist"
    echo "$ref" | diff - "$(public-file)"
}

check-anchor::age-key() {
    local ref
    ref=${1-$(action=generate-public dispatch)}
    log "public keys:"$'\n'"$ref" info
    log "$(get-anchor)" info
    grep -Fxq "$(get-anchor)" <<<"$ref"
}

check-host::age-key() {
    local ref=${1-$(action=generate-public dispatch)}
    local host_priv host_pub

    log "check host..." info

    host_priv="$(try ssh "$(key-admin)@$(fqdn)" "cat $(host-key-file)")" ||
        die 1 "failed to retreive key from host"

    # For testing purposes
    [[ $host_priv == "trust-me" ]] && return

    host_pub=$(echo "$host_priv" | age-keygen -y | head -n1) || die
    echo "$ref" | diff - <(echo "$host_pub")
}

check-host::ssh-key() {
    local ref=$1
    log "diff host key" info
    host::pull::ssh-key >"$tmpdir/public_host_key"
    diff <(echo "$ref" | normalize-ssh-key) <(normalize-ssh-key "$tmpdir/public_host_key")
}

normalize-ssh-key() {
    awk '/^ssh-ed25519/ {print $1, $2}' "$@"
}

# --- *::pull::*

host::pull::ssh-key() {
    local public_host_key
    log "ssh-keyscan $(fqdn)" info
    public_host_key=$(try ssh-keyscan -q "$(fqdn)") || die 1 "could not pull host key"
    if [[ $public_host_key == "trust-me" ]]; then
        generate-public::ssh-key
    else
        echo "$public_host_key"
    fi
}

# --- *::sideload::*

host::sideload::age-key() {
    local public_key

    decrypt
    public_key="$(action=generate-public dispatch)"

    # shellcheck disable=SC2015
    check-public "$public_key" && check-anchor::age-key "$public_key" ||
        die 1 "Error: Keys are out of sync, run '$0 $entity sync age-key' first"

    check-host::age-key "$public_key" &&
        die 1 "current key is already active"

    try ssh "$(key-admin)@$(fqdn)" "head -n 3 $(host-key-file)" >>"$(private-file)"
    try scp "$(private-file)" "$(key-admin)@$(fqdn):$(host-key-file)" >/dev/null
    log "rebuild host '$entity' now or suffer the consequences" warning
}

# --- *::factory-reset::*

host::factory-reset() {
    local extra_files="$tmpdir/extra-files"
    local luks_key="$tmpdir/luks_key"
    local store="$extra_files/srv/storage"
    local age_key="$store/etc/age/keys.txt"

    install -d -m700 "$(dirname "$age_key")"

    type=luks-key decrypt && cp "$(private-file)" "$luks_key"
    type=age-key decrypt && cp "$(private-file)" "$age_key"

    chmod 600 "$age_key"
    cp -a "$store/." "$extra_files"

    log "luks key prepared: $(cat "$luks_key")" info
    log "age key prepared: $(sed -n '3p' "$age_key")" info
    log "these extra files will be copied:" info
    tree -a "$extra_files"

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
    try age-keygen >"$(private-file)"
}

create-private::ssh-key() {
    try ssh-keygen -q -t "ed25519" -f "$(private-file)" -N "" \
        -C "$mode-key-$(date +%Y-%m-%d)" <<<y >/dev/null
}

create-private::wg-key() {
    try wg genkey >"$(private-file)"
}

create-private::luks-key() {
    try gen-passwd >"$(private-file)"
}

create-private::tls-cert() {
    try openssl genpkey -algorithm ED25519 -out "$(private-file)"
}

create-private::passwd() {
    try gen-passwd >"$(private-file)"
}

create-private::mail() {
    create-private::passwd
}
# --- *::generate-public::*

generate-public::age-key() {
    try age-keygen -y <"$(private-file)"
}

generate-public::ssh-key() {
    try ssh-keygen -y -f "$(private-file)"
}

generate-public::wg-key() {
    try wg pubkey <"$(private-file)"
}

generate-public::tls-cert() {
    try openssl req -new -x509 -key "$(private-file)" \
        -subj "/CN=*.$entity" \
        -addext "subjectAltName=DNS:*.$entity,DNS:$entity" \
        -nodes -out - -days 3650
}

# --- *::verify::*

verify::age-key() {
    action=generate-public dispatch >/dev/null
}

verify::ssh-key() {
    action=generate-public dispatch >/dev/null
}

verify::wg-key() {
    action=generate-public dispatch >/dev/null
}

verify::tls-cert() {
    action=generate-public dispatch >/dev/null
}

verify::luks-key() {
    log "luks-key: $(cat "$(private-file)")" info
}

verify::mail() {
    verify::passwd
}

verify::passwd() {
    head -n1 "$(private-file)" | grep -qE '^.{12,}$'
}

verify::mail-hashed() {
    verify::passwd-hashed
}

verify::passwd-hashed() {
    [[ "$(cat "$(private-file)")" =~ ^\$6\$[^$]+\$[./0-9A-Za-z]+$ ]]
}

# --- *::init::*

init() {
    mkdir -p "$(dirname "$(secrets-file)")"

    create-private::age-key
    generate-public::age-key | insert-anchor
    update-creation-rules

    # shellcheck disable=SC2094
    # SC believes we're reading from $(secrets-file) here but --filename-override
    # simply tells sops what creation rule to use.
    echo "init: true" | try sops encrypt \
        --filename-override "$(secrets-file)" \
        /dev/stdin >"$(secrets-file)" || die 1 "could not create $(secrets-file)"

    encrypt
}

# --- sops integrations

encrypt() {

    action=verify dispatch || die 1 "verification failed"

    if [[ $mode == "root" ]]; then
        cat "$(private-file)" >>"$SOPS_AGE_KEY_FILE"
    else
        log "encrypting secret > $(secrets-path)@$(secrets-file)" debug
        try sops set "$(secrets-file)" "$(secrets-path)" "$(jq -Rs <"$(private-file)")"
    fi

}

decrypt() {
    if [[ $mode == "root" ]]; then
        cat "$SOPS_AGE_KEY_FILE" >>"$(private-file)"
    else
        log "decrypting secret < $(secrets-path)@$(secrets-file)" info
        try sops decrypt --extract "$(secrets-path)" "$(secrets-file)" >"$(private-file)"
    fi
}

get-anchor() {
    yq-sops '.entities.$mode-$entity // error("Anchor $mode-$entity not found in .sops.yaml")'
}

upsert-anchor() {
    local query='with(.entities.$mode-$entity; . = "$age_key" | . anchor = "$mode-$entity")'
    age_key=$(cat) yq-sops "$query" -i
}

insert-anchor() {
    yq-sops '.entities | has("$mode-$entity") | not' >/dev/null || die 1 "anchor exists"
    upsert-anchor
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
        try yq -e "$query" .sops.yaml | envsubst || die 1 "could not get $query"
    fi
}

init-sops-yaml() {
    [[ -f .sops.yaml ]] &&
        die 1 "will not overwrite existing .sops.yaml"

    cat >.sops.yaml <<'EOF'
key-file: ./keys.txt
host-key-file: /etc/age/keys.txt
dns-suffix: .local
key-admin: keyservice

secrets:
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

private-file() {
    local pf="$tmpdir/$mode.$entity.$type.private"
    if [[ ! -f $pf ]]; then
        touch "$pf"
        chmod 600 "$pf"
        log "$pf *exists*" debug
    fi
    echo "$pf"
}

set-key-admin() {
    (
        mode=user
        entity=$(key-admin)
        type=ssh-key
        decrypt
    ) || log "user '$(key-admin)' doesn't have an ssh key, host checks wont work." warning
}

fqdn() {
    echo "$entity@$(yq-sops ".host-key-file")"
}

host-key-file() {
    yq-sops ".host-key-file"
}

key-admin() {
    yq-sops ".key-admin"
}

public-file() {
    case $type in
    tls-cert) pubext="pem" ;;
    *) pubext="pub" ;;
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
    local key=$1 template
    template="$(yq ".secrets.$mode" .sops.yaml)"
    glob=$(sed -E 's:/\{[^}]+\}/:/**/:g; s:\{[^}]+\}:*:g' <<<"$template")

    eval "files=($glob)"

    if [[ "${files[0]}" == "$glob" ]]; then
        return 0
    fi

    echo "${files[@]}"
}

copy-private() {
    try cat "$PRIVATE_FILE" >"$(private-file)"
}

gen-passwd() {
    try openssl rand -base64 12
}

# --- main
main "$@"
