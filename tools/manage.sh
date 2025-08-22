#!/usr/bin/env bash
# shellcheck disable=SC2317

set -euo pipefail
shopt -s globstar

usage() {
    cat <<'EOF'

Usage: ./tools/manage.sh <-h|-u|-d> <host|user|domain> <action> [<type>]
EOF
}

usage-full() {
    less <<'EOF'

DESCRIPTION
    This script is for managing secrets within a SOPS-based infrastructure.
    It automates the generation, encryption, synchronization, and deployment
    of various ephemeral keys and credentials. The core principle is that all
    secrets are protected by a master age-key, allowing the rest of the secrets
    to be disposable.

USAGE
    ./tools/manage.sh <-h|-u|-d> <host|user|domain> <action> [<type>]
    ./tools/manage.sh -u <user> bootstrap
    ./tools/manage.sh -h <host> factory-reset
    ./tools/manage.sh updatekeys
    ./tools/manage.sh --help

MODES
    The MODE argument determines the context of the operation.

    -h, --host    Manage secrets for a specific host.
                  Example: `./tools/manage.sh -h server1 new age-key`

    -u, --user    Manage secrets for a specific user.
                  Example: `./tools/manage.sh -u jane.doe new ssh-key`

    -d, --domain  Manage secrets for a specific domain.
                  Example: `./tools/manage.sh -d example.com check tls-cert`

ACTIONS
    The ACTION argument specifies the operation to perform.

    init          Initializes a new entity (host, user, etc.) by creating its
                  secrets file and adding a key group reference to `.sops.yaml`.

    new           A composite action that first runs `new-private` to create and
                  encrypt a new secret, then runs `sync` to generate and save
                  the corresponding public component.

    new-private   Generates a new private key/resource and encrypts it into the
                  appropriate secrets file. The public component is not created.
                  If the `PRIVATE_FILE` environment variable is set, its
                  contents are used instead of generating a new key.

    sync          Decrypts a private resource to generate its public counterpart.
                  - For `age-key`, this also updates the key's anchor in
                    `.sops.yaml` and triggers `sops updatekeys`.
                  - For `passwd`/`mail`, it creates a hashed version of the
                    password for storage.

    check         Verifies the integrity and consistency of secrets.
                  - For key pairs, it confirms the public key matches the
                    private key.
                  - For hosts, it remotely verifies the deployed SSH/Age key.
                  - For `passwd`, it verifies the plaintext and hashed versions.

    pull          (Host SSH keys only) Retrieves the public SSH key from a remote
                  host via `ssh-keyscan` and writes it to the entitys public file.

    sideload      (Age keys only) Deploys the private key to a remote host.

    factory-reset (Hosts only) Uses `nixos-anywhere` to reinstall a host from
                  scratch, pre-seeding it with its existing LUKS, SSH, and Age keys
                  from the secrets store.

SPECIAL ACTIONS
    -u <admin> bootstrap
        Initialize the secret management system with a new administrative user.
        It should only be run once and performs the following critical steps:
        1. Creates a default `.sops.yaml` configuration if one does not exist.
        2. Generates a new master Age key pair.
        3. Saves the private master key to the path specified in `.sops.yaml`
           (e.g., `./age.key`). This file is the root of all trust and MUST be
           backed up and kept secure.
        4. In `.sops.yaml`, it records the public master key under an anchor
           for the specified admin user (e.g., `&user-admin`).
        5. Encrypts the admin's private Age key into their own secrets file,
           protected by the master key itself.

        This establishes a model where one or more admins hold the master key(s),
        while all other keys (for hosts, users, etc.) are ephemeral and can be
        rotated and managed safely within a Git repository.

    updatekeys
        Scans all secret files and updates their SOPS metadata. This is done
        automatically after changing a master Age key or adding a new recipient
        to a file's `key_groups` in `.sops.yaml`. It ensures all files can be
        decrypted by the currently configured keys.

KEY / RESOURCE TYPES
    The TYPE argument specifies the kind of secret to manage.

    age-key     Age encryption key pair.
    ssh-key     SSH key pair (Ed25519).
    wg-key      WireGuard key pair.
    luks-key    A passphrase for LUKS disk encryption.
    passwd      A user's login password (stored as a salted SHA-512 hash).
    mail        An email account password (handled like `passwd`).
    tls-cert    A TLS certificate and its private key.

ENVIRONMENT VARIABLES
    SOPS_AGE_KEY_FILE
        Path to the master Age private key file. The script sets this
        automatically based on the `.sops.yaml` configuration.

    DEBUG=true
        Enables verbose debug logging, showing function calls and detailed steps.

    PRIVATE_FILE=<path>
        If set during a `new-private` action, the script will use the contents
        of the specified file as the private key instead of generating a new one.

CONFIGURATION: .sops.yaml
    The script parses it to understand the repository's structure and encryption
    rules. Key sections include:

    `keys`: Defines YAML anchors for Age public keys, which are used to grant
    decryption rights. The `bootstrap` command sets up the first admin key here.

    `env`: Defines environment variables, most importantly `SOPS_AGE_KEY_FILE`,
    which tells SOPS where to find the master private key for decryption.

    Path Templates (`host-secrets`, `user-secrets`, `domain-secrets`):
    The script uses these special keys to dynamically determine the location
    of a secret. A template like ` "['{type}'] hosts/{host}/secrets.yaml" `
    is parsed to determine both the file path (`hosts/{host}/secrets.yaml`)
    and the JSON/YAML path within that file (`['{type}']`). The script
    substitutes placeholders like `{host}` and `{type}` with the provided
    arguments.
EOF
}

main() {
    setup "$@"

    sanitize-dispatcher-input && dispatch
    exit_code=$?

    case $exit_code in
    0) log "$mode::$action::$type completed" success ;;
    *) log "$mode::$action::$type completed with errors" error ;;
    esac

    log "exit code: $exit_code" debug
    exit $exit_code
}

# --- utils

log() {
    local \
        log=false \
        msg=$1 \
        level=$2 \
        caller=${FUNCNAME[1]} \
        depth=${#FUNCNAME[@]}

    if [[ $caller == die ]]; then
        caller=${FUNCNAME[2]}
    fi

    if [[ $caller == try ]]; then
        caller=${FUNCNAME[3]}
    fi

    case $level in
    success) msg="[$depth]: $GB${caller}$GN: $msg$NC" ;;
    debug) msg="[$depth]: $YB${caller}$NC: $msg$NC" ;;
    info) msg="[$depth]: $BB${caller}$BN: $msg$NC" ;;
    warning) msg="[$depth]: $YN${caller}$YB: $msg$NC" ;;
    error) msg="[$depth]: $RB${caller}$RN: $msg$NC" ;;
    esac

    case $level in
    warning | error | success | info)
        log=true
        ;;
    *)
        if [[ ${DEBUG:-} == true ]]; then
            log=true
        fi
        ;;
    esac

    if [[ $log == true ]]; then
        echo -e "$msg" >&2
    fi
}

die() {
    local \
        exit_code=${1-$?} \
        msg=${2-$(tr -d '\r' <"$err")} \
        fn=${3-}

    case $exit_code in
    0) log "$msg" info ;;
    *) log "$msg (exit $exit_code)" error ;;
    esac

    [[ -n "$fn" ]] && "$fn"

    log "exit code $exit_code" debug
    exit "$exit_code"
}

try() {
    local stderr_file output exit_code
    stderr_file=$(mktemp)
    output=$("$@" 2>"$stderr_file")
    exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo "$output"
    else
        die "$exit_code" "$(tr -d '\r' <"$stderr_file")"
    fi
    rm "$stderr_file"
}

fn-exists() {
    local fn=$1
    declare -F "$fn" >/dev/null
}

setup() {
    domain="kompismoln.se"

    # bold or not bold red green yellow and normal colors
    RN='\033[0;31m'
    RB='\033[1;31m'
    GN='\033[0;32m'
    GB='\033[1;32m'
    YN='\033[0;33m'
    YB='\033[1;33m'
    BN='\033[0;34m'
    BB='\033[1;34m'
    NC='\033[0m'

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    err="$tmp/.err"
    touch "$err"

    out="$tmp/.out"
    touch "$out"

    private_file="$tmp/private_file"
    touch "$private_file"
    chmod 600 "$private_file"
    log "$private_file *exists*" debug

    [[ $# -ge 1 ]] || die 1 "hello! try --help" usage
    mode=$1

    case $mode in
    -h | -u | -d)
        [[ $# -ge 3 ]] || die 1 "wrong number of arguments provided." usage
        entity=$2
        action=$3
        type=${4-}
        ;;

    --help)
        usage-full
        exit 0
        ;;
    updatekeys)
        updatekeys
        exit 0
        ;;
    *) die 1 "invalid mode: $mode" usage ;;
    esac

    actions=(new new-private sync check init)

    case $mode in
    -h)
        mode="host"
        host=$entity
        types=(age-key ssh-key wg-key luks-key)

        [[ $action == "factory-reset" ]] && type=age-key
        [[ $type == "ssh-key" ]] && actions+=(pull)
        [[ $type == "age-key" ]] && actions+=(sideload factory-reset)
        ;;
    -u)
        mode="user"
        user=$entity
        types=(age-key ssh-key passwd mail)
        [[ $action == "bootstrap" ]] && {
            type=age-key
            actions+=(bootstrap)
            init-sops-yaml
        }
        ;;
    -d)
        mode="domain"
        domain=$entity
        types=(tls-cert)
        ;;
    esac

    if [[ $action == "init" ]]; then
        types+=("")
    fi

    SOPS_AGE_KEY_FILE=$(.sops-yaml '.env.SOPS_AGE_KEY_FILE')
    [[ -z $SOPS_AGE_KEY_FILE ]] && die 1 "SOPS_AGE_KEY_FILE is empty"
    export SOPS_AGE_KEY_FILE

    public_file=$(.sops-yaml ".$mode-pub")

    set-secrets-location
}

sanitize-dispatcher-input() {
    # shellcheck disable=SC2076
    [[ " ${actions[*]} " =~ " $action " ]] ||
        die 1 "'$action' is not an action. Allowed actions: ${actions[*]}" usage

    # shellcheck disable=SC2076
    [[ " ${types[*]} " =~ " $type " ]] ||
        die 1 "'$type' is not a valid key type. Allowed key types: ${types[*]}" usage

    [[ $action == "bootstrap" || $action == "init" || -f "$secrets_file" ]] || {
        die 1 "no file found in '$secrets_file', did you spell $mode correctly?"
    }
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

# --- *::sync::*
# Decrypt a private resource and use it to generate and save/replace a public key

sync() {
    decrypt
    action=generate-public dispatch >"$public_file"
}

sync::age-key() {
    sync && sync::age-key--sops
}

sync::age-key--sops() {
    local age_key new_age_key

    age_key="$(cat "$public_file")"

    set-anchor "$age_key"
    new_age_key=$(get-anchor)

    if [[ -z "$new_age_key" ]]; then
        log "ssh-key '$mode-$entity' doesn't have an anchor in .sops.yaml." warning
        return 0
    fi

    if [[ "$age_key" != "$new_age_key" ]]; then
        die 127 "unexpected code path, '$mode-$entity' was not correctly updated."
    else
        updatekeys
    fi
}

sync::luks-key() {
    return 0
}

# Linux passwords are famously hashed so we need to encrypt both plain and
# hashed format and keep them in sync.
user::sync::passwd() {
    decrypt

    cp "$private_file" "$private_file.plain"
    mkpasswd -sm sha-512 <"$private_file" >"$private_file.hash"
    cp "$private_file.hash" "$private_file"

    type=$type-hashed encrypt
    cp "$private_file.plain" "$private_file"
}

# nixos-mailserver uses linux-like password management
user::sync::mail() {
    user::sync::passwd
}

# --- *::check::*

diff--public-file() {
    log "diff public file" info
    [[ -f $public_file ]] || die 1 "public key doesn't exist"
    echo "$1" | diff - "$public_file"
}

diff--sops-anchor() {
    log "diff sops anchor" info
    echo "$1" | diff - <(get-anchor)
}

host::check::age-key() {
    local exit_code=0 host_priv host_pub
    decrypt
    ref="$(action=generate-public dispatch)"

    diff--public-file "$ref" || exit_code=1
    diff--sops-anchor "$ref" || exit_code=1

    log "diff host key" info
    host_priv="$(try ssh "admin@$host.$domain" "cat /etc/age/keys.txt")"
    [[ $host_priv == "trust-me" ]] && return "$exit_code"
    host_pub=$(echo "$host_priv" | age-keygen -y | head -n1) || die
    echo "$ref" | diff - <(echo "$host_pub") || exit_code=1

    return "$exit_code"
}

host::check::ssh-key() {
    local exit_code=0 host_pub
    decrypt
    ref="$(action=generate-public dispatch)"

    diff--public-file "$ref" || exit_code=1

    log "diff host key" info
    host_pub=$(ssh-keyscan -q "$host.$domain" | cut -d' ' -f2-3) || die
    [[ $host_pub == "trust-me" ]] && return "$exit_code"
    echo "$ref" | cut -d' ' -f1-2 | diff - <(echo "$host_pub") || exit_code=1

    return "$exit_code"
}

host::check::wg-key() {
    decrypt
    diff--public-file "$(action=generate-public dispatch)"
}

host::check::luks-key() {
    decrypt

    ssh "admin@$host.$domain" \
        'sudo cryptsetup open --test-passphrase --key-file=- /dev/sda3' \
        2>"$err" <"$private_file" || die
}

user::check::age-key() {
    local exit_code=0 ref
    decrypt
    ref="$(action=generate-public dispatch)"

    diff--public-file "$ref" || exit_code=1
    diff--sops-anchor "$ref" || exit_code=1

    return "$exit_code"
}

user::check::ssh-key() {
    decrypt
    diff--public-file "$(action=generate-public dispatch)"
}

user::check::passwd() {
    local salt
    # shellcheck disable=SC2015
    decrypt && cp "$private_file" "$private_file.plain" || die
    type=$type-hashed decrypt

    salt=$(awk -F'$' '{print $3}' "$private_file")
    mkpasswd -m sha-512 -S "$salt" "$(cat "$private_file.plain")" |
        diff - "$private_file"
}

user::check::mail() {
    user::check::passwd
}

domain::check::tls-cert() {
    local exit_code=0 san key cert

    decrypt

    if ! openssl x509 -in "$public_file" -checkend 2592000 >/dev/null 2>&1; then
        log "Certificate expires within 30 days" warning
        exit_code=1
    fi

    san=$(openssl x509 -in "$public_file" -noout -ext subjectAltName 2>/dev/null |
        grep -E "DNS:" | sed 's/.*DNS://g' | tr ',' '\n' | sort)

    if [[ "$san" != *"$domain"* ]]; then
        log "Domain $domain not found in SAN: $san" warning
        exit_code=1
    fi

    key=$(openssl pkey -in "$private_file" -pubout)
    cert=$(openssl x509 -in "$public_file" -pubkey -noout)

    if [[ "$key" != "$cert" ]]; then
        log "Public key mismatch between certificate and private key" error
        exit_code=1
    fi

    log "Certificate public key: $(echo "$cert" | sed -n '2p')" info

    return "$exit_code"
}

# --- *::pull::*

host::pull::ssh-key() {
    ssh-keyscan -q "$host.$domain" | cut -d' ' -f2-3 >"$public_file"
}

# --- *::sideload::*

host::sideload::age-key() {
    local host_key=/etc/age/keys.txt

    # shellcheck disable=SC2015
    check::age-key && check::age-key--sops ||
        die 1 "Error: Keys are out of sync, run '$0 $host sync age-key' first"

    check::age-key--host &&
        die 1 "current key is already active"

    # shellcheck disable=SC2029
    ssh "admin@$host.$domain" "head -n 3 $host_key" 2>"$err" >>"$private_file" || die
    scp "$private_file" "admin@$host.$domain:$host_key" >"$out" 2>"$err" || die
    log "rebuild $host now or suffer the consequences" warning
}

# --- *::factory-reset::*

host::factory-reset() {
    local extra_files="$tmp/mnt"
    local luks_key="$tmp/luks_key"
    local store="$extra_files/srv/storage"
    local ssh_host_key="$store/etc/ssh/ssh_host_ed25519_key"
    local age_key="$store/etc/age/keys.txt"

    install -d -m755 "$(dirname "$ssh_host_key")"
    install -d -m700 "$(dirname "$age_key")"

    type=luks-key decrypt && cp "$private_file" "$luks_key"
    type=ssh-key decrypt && cp "$private_file" "$ssh_host_key"
    type=age-key decrypt && cp "$private_file" "$age_key"

    chmod 600 "$ssh_host_key" "$age_key"
    cp -a "$store/." "$extra_files"

    log "luks key prepared: $(cat "$luks_key")" info
    log "age key prepared: $(sed -n '3p' "$age_key")" info
    log "ssh host key prepared: $(sed -n '3p' "$ssh_host_key")" info
    log "these extra files will be copied:" info
    tree -a "$extra_files"

    nixos-anywhere \
        --flake ".#$host" \
        --target-host root@"$host.$domain" \
        --ssh-option GlobalKnownHostsFile=/dev/null \
        --disk-encryption-keys /luks-key "$luks_key" \
        --generate-hardware-config nixos-facter hosts/"$host"/facter.json \
        --extra-files "$extra_files" \
        --copy-host-keys 2>"$err" || die
}

# --- *::create-private::*

create-private::age-key() {
    rm "$private_file"
    age-keygen >"$private_file" 2>"$err" || die
}

create-private::ssh-key() {
    ssh-keygen -q -t "ed25519" -f "$private_file" -N "" \
        -C "$mode-key-$(date +%Y-%m-%d)" <<<y >/dev/null 2>"$err" || die
}

create-private::wg-key() {
    wg genkey >"$private_file" 2>"$err" || die
}

create-private::luks-key() {
    openssl rand -base64 12 >"$private_file" 2>"$out" || die
}

create-private::tls-cert() {
    openssl genpkey -algorithm ED25519 -out "$private_file" 2>"$err" || die
}

create-private::passwd() {
    read -r -p "Enter password: " password
    echo "$password" >"$private_file"
}

# --- *::generate-public::*

generate-public::age-key() {
    age-keygen -y <"$private_file" 2>"$err" || die
}

generate-public::ssh-key() {
    ssh-keygen -y -f "$private_file" 2>"$err" || die
}

generate-public::wg-key() {
    wg pubkey <"$private_file" 2>"$err" || die
}

generate-public::tls-cert() {
    openssl req -new -x509 -key "$private_file" \
        -subj "/CN=*.$domain" \
        -addext "subjectAltName=DNS:*.$domain,DNS:$domain" \
        -nodes -out - -days 3650 2>"$err" || die
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
    log "luks-key: $(cat "$private_file")" info
}

# TODO: make a more comprehensive security audit on passwd
verify::passwd() {
    [[ -s "$private_file" && -n "$(cat "$private_file")" ]] || {
        log "password is empty" error
        return 1
    }
}

verify::passwd-hashed() {
    local \
        salt \
        password \
        from_secret \
        from_password

    read -r -p "Verify password: " password 2>/dev/tty

    from_secret=$(cat "$private_file")
    salt=$(awk -F'$' '{print $3}' "$private_file")

    from_password=$(mkpasswd -m sha-512 -S "$salt" "$password")

    [[ "$from_secret" == "$from_password" ]] || {
        log "password doesn't match" error
        return 1
    }
}

# --- *::init::*

init() {
    mkdir -p "$(dirname "$secrets_file")"

    sed -i "1a\ \ - &$mode-$entity" .sops.yaml
    cat >>.sops.yaml <<EOF
  - path_regex: $secrets_file
    key_groups:
      - age:
        - *user-admin
        - *$mode-$entity
EOF
    # shellcheck disable=SC2094
    echo "init: true" | sops encrypt \
        --filename-override "$secrets_file" \
        /dev/stdin >"$secrets_file" 2>"$err" || die
}

# --- sops integrations
encrypt() {
    set-secrets-location
    log "encrypting secret > $secrets_path@$private_file" debug

    action=verify dispatch 2>"$err" || die
    sops set "$secrets_file" "$secrets_path" "$(jq -Rs <"$private_file")" >"$out" 2>"$err" || die
}

decrypt() {
    set-secrets-location
    log "decrypting secret < $secrets_path@$private_file" debug

    sops decrypt --extract "$secrets_path" "$secrets_file" >"$private_file" 2>"$err" || die
}

get-anchor() {
    yq "(.keys[] | select(anchor == \"$mode-$entity\"))" .sops.yaml 2>"$err" || die
}

set-anchor() {
    local age_key=$1 new_age_key

    [[ -z $age_key ]] && die 1 "age key invalid: '$age_key'"

    yq -i "(.keys[] | select(anchor == \"$mode-$entity\")) |= \"$age_key\"" .sops.yaml 2>"$err" || die

    new_age_key=$(get-anchor)
    [[ "$new_age_key" == "$age_key" ]] || die 1 "update fail: $new_age_key != $age_key"
}

updatekeys() {
    local mode

    for mode in user host domain; do

        files=$(secrets-glob $mode)

        [[ -z "${files[*]}" ]] && {
            log "no secrets in $mode: skipping" info
            continue
        }

        log "<$mode>" info
        # shellcheck disable=SC2068
        sops updatekeys -y ${files[@]}
        log "</$mode>" info
    done
}

# --- misc helpers

secrets-glob() {
    local key=$1 template
    IFS=" " read -r _ template <<<"$(yq ".$key-secrets" .sops.yaml 2>"$err")"
    glob=$(sed -E 's:/\{[^}]+\}/:/**/:g; s:\{[^}]+\}:*:g' <<<"$template")

    eval "files=($glob)"

    # shellcheck disable=SC2068
    # shellcheck disable=SC2154
    if [[ "${files[0]}" == "$glob" ]]; then
        return 0
    fi

    echo "${files[@]}"
}

set-secrets-location() {
    IFS=" " read -r secrets_path secrets_file <<<"$(.sops-yaml ".$mode-secrets")"
}

copy-private() {
    cat "$PRIVATE_FILE" >"$private_file" 2>"$err" || die
}

bootstrap() {
    local key

    mkdir -p "$(dirname "$secrets_file")"
    touch "$secrets_file"

    create-private::age-key
    cp -a "$private_file" "$SOPS_AGE_KEY_FILE"

    key=$(generate-public::age-key)
    set-anchor "$key"

    echo "$user: { age-key: }" | sops encrypt \
        --filename-override "users/$user-enc.yaml" \
        /dev/stdin >"$secrets_file" 2>"$err" || die

    encrypt

    sync::age-key
}

.sops-yaml() {
    local key=$1 template

    log "get '$key'" debug
    template=$(yq "$key" .sops.yaml 2>"$err") || die
    eval "echo \"${template//\{/\$\{}\"" 2>"$err" || die
}

init-sops-yaml() {
    [ -f .sops.yaml ] &&
        die 1 "will not overwrite existing .sops.yaml"

    cat >.sops.yaml <<EOF
keys:
  - &user-$user

env:
    SOPS_AGE_KEY_FILE: ./age.key

host-secrets: "['{type}'] hosts/{host}/secrets.yaml"
user-secrets: "['{user}']['{type}'] users/{user}-enc.yaml"
domain-secrets: "['{domain}']['{type}'] domains/{domain}-enc.yaml"

host-pub: hosts/{host}/{type}.pub
user-pub: users/{user}-{type}.pub
domain-pub: domains/{domain}-{type}.pem

creation_rules:
  - path_regex: users/$user-enc.yaml
    key_groups:
      - age:
        - *user-$user
EOF
}

main "$@"
