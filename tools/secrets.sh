#!/usr/bin/env bash

set -uo pipefail
shopt -s globstar

usage() {
    cat <<'EOF'

Usage: secrets -h <host> <action> <type>
       secrets -u <user> <action> <type>
       secrets -d <domain> <action> <type>
       secrets updatekeys

actions:      new | sync | check | sideload
host types:   ssh-key | wg-key
user types:   ssh-key | passwd | mail
domain types: tls-cert

EOF
}

usage-full() {
    usage
    cat <<'EOF'
    `secrets` manages sops-encrypted secrets (private keys, passwords, tls-certs and wireguard) together with their corresponding components (e.g. public keys, hashed passwords) for hosts and users within the repository.

MODES:
  -h <hostname>
        Acts on the hosts' secrets at 'hosts/<hostname>/secrets.yaml
        ssh-key writes public keys to 'hosts/<hostname>/<type>.pub'.

  -u <username>
        Acts on users' secrets at 'users/<username>-enc.yaml
        `ssh-key` writes public keys 'users/<username>-<type>.pub'.

  -d <domainname>
        Acts on domain related secrets at 'domains/secrets.yaml'.
        `tls-cert` write certificates to 'domains/<domain>-tls-cert.pem'.

  updatekeys
        Runs `sops updatekeys` on all paths above.
ARGUMENTS:
  <action>
        Must be one of:

        - new:      Creates a new secret (e.g., key pair, password). For keys,
                    this generates a new private/public pair, encrypts the
                    private part into the secrets file, and saves the public
                    part to the corresponding '.pub' file.
                    WARNING: This overwrites existing secrets and keys.

        - sync:     Re-generates and overwrites the public key file using the
                    existing encrypted private key. Useful if the public key
                    is missing or suspected to be out of sync.

        - check:    Performs consistency checks. For keys, it verifies the
                    public key on disk against the encrypted private key.
                    For SSH keys, it performs additional checks against the
                    '.sops.yaml' configuration and the remote host.

        - sideload: [Host Mode, ssh-key only] Sideload a decrypted private
                    SSH key to the target host's via scp/ssh.

                    The new key replaces
                    /etc/ssh/ssh_host_ed25519_key
                    which is renamed to
                    /etc/ssh/ssh_host_ed25519_key-
                    (sops-nix uses both)
                    
                    Requires remote sudo privileges.

  <type>
        The type of secret to manage. The available types depend on the mode.

        Available for Host Mode (-h):
        - ssh-key:  An Ed25519 SSH host key.
        - wg-key:   A Curve25519 WireGuard private key.

        Available for User Mode (-u):
        - ssh-key:  A user's Ed25519 SSH key.
        - passwd:   A user's password. The script will prompt for input.
                    A SHA-512 hashed version is also stored as 'passwd-hashed'.
        - mail:     A user's mail password (behaves identically to 'passwd').

        Available for Domain Mode (-d):
        - tls-cert:

ENVIRONMENT VARIABLES:
  SECRET
        When running the 'new' action, if this variable is set to a file
        path, the script will use the content of that file as the private
        key instead of generating a new one.

EXAMPLES:
  # Create a new SSH key pair for 'server01' and update sops recipients
  secrets -h server01 new ssh-key

  # Use an existing private SSH to renew key pair for 'server01' and update
  # sops recipients
  SECRET=./ssh_host_ed25519_key secrets -h server01 new ssh-key

  # Check if all keys for 'server01' (on disk, in sops, on host) match
  secrets -h server01 check ssh-key

  # Deploy the verified host key to 'server01'
  secrets -h server01 sideload ssh-key

  # Set a new password for user 'jane'
  secrets -u jane new passwd

  # A WireGuard public key is outdated; regenerate it from the secret
  secrets -h vpn-host sync wg-key

EOF
}

main() {
    setup "$@" && validate

    dispatch
    exit_code=$?

    case $exit_code in
    0) log "$mode::$action::$type completed" success ;;
    *) log "$mode::$action::$type completed" error ;;
    esac

    log "exit code: $exit_code" debug
}

# --- utils

# instead of `echo`
DEBUG=true
log() {
    local msg=$1 level=${2-} caller=${FUNCNAME[1]} depth=${#FUNCNAME[@]}

    case $caller in
    die | post-cmd) caller=${FUNCNAME[2]} ;;
    esac

    case $level in
    success) msg="[$depth]$GB${caller}$GN: $msg$NC" ;;
    debug) msg="[$depth]$YB${caller}$NC: $msg$NC" ;;
    info) msg="[$depth]$YB${caller}$YN: $msg$NC" ;;
    warning) msg="[$depth]$YN${caller}$YB: $msg$NC" ;;
    error) msg="[$depth]$RB${caller}$RN: $msg$NC" ;;
    esac

    [[ $DEBUG == true ]] && echo -e "$msg" >&2
}

# die with mandatory exit code and optional message
die() {
    local exit_code=$1 msg=$2 fn=${3-}

    case $exit_code in
    0) log "$msg" info ;;
    *) log "$msg" error ;;
    esac

    fn-exists "$fn" && $fn

    exit "$exit_code"
}

#  switch for exit codes from commands with side effects
post-cmd() {
    local exit_code=$1 error_msg=${2-} msg=${3-}

    case $exit_code in
    0) log "$msg" success ;;
    *) die "$exit_code" "$error_msg" ;;
    esac
}

# misc 'setup the environment' thingies
setup() {
    log "hello" debug

    # bold or not bold red green yellow and normal colors
    RN='\033[0;31m'
    RB='\033[1;31m'
    GN='\033[0;32m'
    GB='\033[1;32m'
    YN='\033[0;33m'
    YB='\033[1;33m'
    NC='\033[0m'

    [[ $# -ge 1 ]] || die 1 "hello! try --help" usage

    case $1 in
    -h | -u | -d)
        [[ $# == 4 ]] || die 2 "wrong number of arguments provided." usage
        mode=$1
        entity=$2
        action=$3
        type=$4
        ;;
    --help)
        usage-full
        exit 0
        ;;
    updatekeys)
        updatekeys
        exit 0
        ;;
    *) die "invalid mode: $1" 1 usage ;;
    esac
    log "$mode::$entity::$action::$type" debug

    script_path="$(dirname "${BASH_SOURCE[0]}")"
    private_file=$(mktemp)
    trap 'rm -f "$private_file"' EXIT
    log "$private_file *exists*" debug

    # minimal action support
    actions=(new sync check)

    case $mode in
    -h)
        mode="host"
        host=$entity
        types=(ssh-key wg-key)
        secrets_file="hosts/$host/secrets.yaml"
        ;;
    -u)
        mode="user"
        user=$entity
        types=(ssh-key passwd mail)
        secrets_file="users/$user-enc.yaml"
        ;;
    -d)
        mode="domain"
        domain=$entity
        types=(tls-cert)
        secrets_file="domains/$domain-enc.yaml"
        ;;
    esac

    case "$mode::$type" in
    host::ssh-key)
        public_file="hosts/$host/$type.pub"
        actions+=(new-private sideload)
        ;;
    host::wg-key)
        public_file="hosts/$host/$type.pub"
        actions+=(new-private)
        ;;
    user::ssh-key)
        public_file="users/$user-$type.pub"
        actions+=(new-private)
        ;;
    domain::tls-cert)
        public_file="domains/$domain-$type.pem"
        ;;
    esac
}

# secrets_path was needing dynamic evaluation due to action 'passwd' invoking 'passwd-hashed'.
secrets_path() {
    local path
    case "$mode" in
    host) path="[\"$type\"]" ;;
    user) path="[\"$entity\"][\"$type\"]" ;;
    domain) path="[\"$entity\"][\"$type\"]" ;;
    esac
    echo "$path"
}

# make sure actions and types are accepted and that $secrets_file exists
validate() {
    log "hello" debug

    if [[ ! " ${actions[*]} " =~ " $action " ]]; then
        die 1 "'$action' is not an action. Allowed actions: ${actions[*]}" usage
    fi

    if [[ ! " ${types[*]} " =~ " $type " ]]; then
        die 1 "'$type' is not a valid key type. Allowed key types: ${types[*]}" usage
    fi

    if [ ! -f "$secrets_file" ]; then
        die 1 "no file found in '$secrets_file', did you spell $mode correctly?"
    fi
}

# check if a function is defined here
fn-exists() {
    local run=$1
    declare -F "$run" >/dev/null
}

# runs when no function is defined for the combination
cmd-not-found() {
    log "no function found for $mode::$action::$type" error
    return 127
}

# Function dispatcher array - lists functions in priority order until one exists
# Pattern: most specific -> least specific -> fallback
#   1. mode::action::type  (e.g., "host::new::ssh-key")
#   2. mode::action        (e.g., "host::new")
#   3. action::type        (e.g., "new::ssh-key")
#   4. action              (e.g., "new")
#   5. cmd-not-found       (fallback handler)
dispatch() {
    dispatcher=(
        "$mode::$action::$type"
        "$mode::$action"
        "$action::$type"
        "$action"
        cmd-not-found
    )
    for run in "${dispatcher[@]}"; do
        log "$run?" debug
        fn-exists "$run" && break
    done
    log "$run!" info
    $run
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
    if [[ -n ${SECRET+x} ]]; then
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

# SSH keys are also used for encryption so in addition to normal sync we'll
# need to update .sops.yaml.
# TODO: when script is stabilized, update only if anchor differs
sync::ssh-key() {
    sync

    local age_key new_age_key

    age_key="$(ssh-to-age <"$public_file")"

    set-anchor "$age_key"
    new_age_key=$(get-anchor)

    if [[ -z "$new_age_key" ]]; then
        warning "ssh-key '$mode-$entity' doesn't have an anchor in .sops.yaml."
        return 0
    fi

    if [[ "$age_key" != "$new_age_key" ]]; then
        die "unexpected code path, '$mode-$entity' was not correctly updated."
    else
        updatekeys
    fi
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
# Verify that private and public keys match and returns exit code 0 if in sync
# and 1 otherwise

check::ssh-key() {
    log "hello" debug

    local \
        exit_code=0 \
        match=true \
        log_level=success \
        from_secret \
        from_file

    decrypt

    from_secret=$(action=generate-public dispatch)
    log "public key (from secret): $from_secret" info

    [[ -f $public_file ]] || die 1 "public key doesn't exist"
    from_file=$(<"$public_file")
    log "public key (from file): $from_file" info

    if [[ ! "$from_secret" == "$from_file" ]]; then
        exit_code=1
        match=false
        log_level=error
    fi

    log "match: $match" $log_level
    log "exit code: $exit_code" debug

    return $exit_code
}

# Users need to check .sops.yaml as well
user::check::ssh-key() {
    log "hello" debug

    local exit_code=0

    check::ssh-key || exit_code=1
    check::ssh-key--sops || exit_code=1

    log "exit code: $exit_code" debug
    return $exit_code
}

# Hosts need to check .sops.yaml like users and also the live host
host::check::ssh-key() {
    log "hello" debug

    local exit_code=0

    check::ssh-key || exit_code=1
    check::ssh-key--sops || exit_code=1
    check::ssh-key--host || exit_code=1

    log "exit code: $exit_code" debug
    return $exit_code
}

# check's helpers (not dispatchable)
check::ssh-key--sops() {
    log "hello" debug

    local \
        exit_code=0 \
        match=true \
        log_level=success \
        from_secret \
        from_sops

    from_secret=$(ssh-to-age <<<"$("generate-public::$type")")
    log "public key (from secret): $from_secret" info

    from_sops=$(get-anchor)
    log "public key (from .sops.yaml): $from_sops" info

    if [[ ! "$from_secret" == "$from_sops" ]]; then
        exit_code=1
        match=false
        log_level=error
    fi

    log "match: $match" $log_level
    log "exit code: $exit_code" debug

    return "$exit_code"
}

check::ssh-key--host() {
    log "hello" debug

    local \
        exit_code=0 \
        match=true \
        log_level=success \
        from_host \
        from_sops

    from_host=$(ssh-keyscan -q "$host.kompismoln.se" | cut -d' ' -f2-3)
    log "public key (from host): $from_host" info

    from_file=$(cut -d' ' -f1-2 "$public_file")
    log "public key (from host): $from_file" info

    if [[ ! "$from_host" == "$from_file" ]]; then
        exit_code=1
        match=false
        log_level=error
    fi

    log "match: $match" $log_level
    log "exit code: $exit_code" debug

    return "$exit_code"
}

# Password and hashed password should match
user::check::passwd() {
    local \
        match=true \
        exit_code=0 \
        salt \
        hash \
        expected_hash

    type=$type-hashed decrypt
    hash=$(cat "$private_file")
    salt=$(awk -F'$' '{print $3}' "$private_file")

    decrypt
    expected_hash=$(mkpasswd -m sha-512 -S "$salt" "$(cat "$private_file")")

    echo
    echo "Expected hash:"
    echo "$expected_hash"
    echo "Actual hash:"
    echo "$hash"

    if [[ ! "$expected_hash" == "$hash" ]]; then
        exit_code=1
        match=false
    fi

    echo
    if [[ $exit_code == 0 ]]; then
        echo -e "${GB}Match: ${GN}$match${NC}"
    else
        echo -e "${RB}Match: ${RN}$match${NC}"
    fi

    return $exit_code
}

user::check::mail() {
    user::check::passwd
}

domain::check::tls-cert() {
    decrypt
    local exit_code=0 match=true

    echo
    if openssl x509 -in "$public_file" -checkend 2592000 >/dev/null 2>&1; then
        echo "Certificate is still valid for 30 days."
    else
        echo "Certificate will expire within 30 days or is already expired."
        match=false
    fi

    san_from_cert=$(openssl x509 -in "$public_file" -noout -ext subjectAltName 2>/dev/null |
        grep -E "DNS:" | sed 's/.*DNS://g' | tr ',' '\n' | sort)

    echo
    echo "Expected SAN:"
    echo "$domain"
    echo "Certificate SAN:"
    echo "$san_from_cert"

    if [[ ! "$san_from_cert" == "$domain" ]]; then
        exit_code=1
        match=false
    fi

    echo
    private_pubkey=$(openssl pkey -in "$private_file" -pubout)
    echo "Private public key:"
    echo "$private_pubkey"

    echo
    cert_pubkey=$(openssl x509 -in "$public_file" -pubkey -noout)
    echo "Certificate public key:"
    echo "$cert_pubkey"

    if [[ ! "$cert_pubkey" == "$private_pubkey" ]]; then
        exit_code=1
        match=false
    fi

    echo
    if [[ $exit_code == 0 ]]; then
        echo -e "${GB}Match: ${GN}$match${NC}"
    else
        echo -e "${RB}Match: ${RN}$match${NC}"
    fi

    return $exit_code
}

# --- *::sideload::*

sideload::ssh-key() {

    if ! check || ! check::ssh-key--sops; then
        echo
        echo "Error: Keys are out of sync, run '$0 $host sync ssh-key' first" >&2
        exit 1
    fi

    if check::ssh-key--host; then
        echo
        echo "Error: Current key is already active" >&2
        exit 1
    fi

    scp "$private_file" "$host.kompismoln.se:pk"
    scp "$script_path/sideload-ssh-key.sh" "$host.kompismoln.se:"

    ssh -t "$host.kompismoln.se" "
        chmod +x sideload-ssh-key.sh
        sudo ./sideload-ssh-key.sh
        rm -f ./pk
        rm -f ./sideload-ssh-key.sh
    "
}

# --- *::create-private::*

create-private::ssh-key() {
    log "Create private key at $private_file"
    ssh-keygen -q -t "ed25519" -f "$private_file" -N "" \
        -C "$mode-key-$(date +%Y-%m-%d)" <<<y >/dev/null 2>&1
}

create-private::wg-key() {
    log "Create private key at $private_file"
    wg genkey >"$private_file"
}

create-private::tls-cert() {
    log "Create TLS private key at $private_file"
    openssl genpkey -algorithm ED25519 -out "$private_file"
}

create-private::passwd() {
    read -r -p "Enter password: " password
    echo "$password" >"$private_file"
}

# --- *::generate-public::*

generate-public::ssh-key() {
    log "generating " debug
    ssh-keygen -y -f "$private_file"
    post-cmd $? "unusual" "$private_file generated"
}

generate-public::wg-key() {
    wg pubkey <"$private_file"
}

generate-public::tls-cert() {
    openssl req -new -x509 -key "$private_file" \
        -subj "/CN=*.km" \
        -addext "subjectAltName=DNS:*.km,DNS:km" \
        -nodes -out - -days 3650
}

# --- *::verify::*

verify::ssh-key() {
    action=generate-public dispatch >/dev/null
}

verify::wg-key() {
    action=generate-public dispatch >/dev/null
}

verify::tls-cert() {
    action=generate-public dispatch >/dev/null
}

# TODO: make a more comprehensive security audit on passwd
verify::passwd() {
    if [[ -s "$private_file" ]] && [[ -n "$(cat "$private_file")" ]]; then
        return 0
    fi
    echo "password empty" >&2
    return 1
}

verify::passwd-hashed() {
    local \
        salt \
        hash \
        expected_hash \
        password

    read -r -p "Verify password: " password 2>/dev/tty

    hash=$(cat "$private_file")
    salt=$(awk -F'$' '{print $3}' "$private_file")

    expected_hash=$(mkpasswd -m sha-512 -S "$salt" "$password")

    [[ "$expected_hash" == "$(<"$private_file")" ]] || {
        echo "passwords doesn't match" >&2
        return 1
    }
}

# --- sops integrations
encrypt() {
    action=verify dispatch 2>"$private_file.err"
    post-cmd $? "verification failed: $(<"$private_file.err")" "secret verified"

    sops set "$secrets_file" "$(secrets_path)" "$(jq -Rs <"$private_file")" 2>"$private_file.err"
    post-cmd $? "encryption failed: $(head -n 1 "$private_file.err")" "secret encrypted"
}

decrypt() {
    log "decrypting secret > $private_file" debug

    sops decrypt --extract "$(secrets_path)" "$secrets_file" >"$private_file" 2>"$private_file.err"
    post-cmd $? "something seems wrong with $secrets_file: $(cat "$private_file.err")" "secret decrypted"
}

get-anchor() {
    yq "(.keys[] | select(anchor == \"$mode-$entity\"))" .sops.yaml
}

set-anchor() {
    yq -i "(.keys[] | select(anchor == \"$mode-$entity\")) |= \"$1\"" .sops.yaml
}

updatekeys() {
    log "hello" debug

    log "<hosts>" info
    sops updatekeys -y hosts/**/secrets.yaml
    post-cmd $? "fail" "</hosts>"

    log "<users>" info
    sops updatekeys -y users/*-enc.yaml
    post-cmd $? "fail" "</users>"

    log "<domains>" info
    sops updatekeys -y domains/*-enc.yaml
    post-cmd $? "fail" "</domains>"
}

# --- misc helpers

copy-private() {
    log "hello" debug

    local content
    if [[ ! -f $SECRET ]]; then die "'$SECRET' is not a file."; fi
    content=$(<"$SECRET")
    echo "$content" >"$private_file"
}

main "$@"
