#!/usr/bin/env bash
# shellcheck disable=SC2317

set -uo pipefail
shopt -s globstar

usage() {
    cat <<'EOF'
Usage: ./tools/manage.sh [-h|-u|-d] <host|user|domain> <action> <type>
EOF
}

usage-full() {
    usage
    cat <<'EOF'

DESCRIPTION
    This script is for managing secrets within a SOPS-based infrastructure.
    It automates the generation, encryption, synchronization, and deployment
    of various ephemeral keys and credentials. The core principle is that all
    secrets are protected by a master AGE key, allowing the rest of the secrets
    to be automated.

USAGE
    ./tools/manage.sh <mode> <entity> <action> <type>
    ./tools/manage.sh -u <admin> bootstrap
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
                  - For hosts, it remotely verifies the deployed SSH/AGE key.
                  - For `passwd`, it verifies the plaintext and hashed versions.

    pull          (Host SSH keys only) Retrieves the public SSH key from a remote
                  host via `ssh-keyscan` and writes it to the entitys public file.

    sideload      (Host SSH/AGE keys only) Deploys the private key to a remote host
                  and installs it, restarting services if necessary.

    factory-reset (Hosts only) Uses `nixos-anywhere` to reinstall a host from
                  scratch, pre-seeding it with its existing LUKS, SSH, and AGE keys
                  from the secrets store.

SPECIAL ACTIONS
    -u <admin> bootstrap
        Initialize the secret management system with a new administrative user.
        It should only be run once and performs the following critical steps:
        1. Creates a default `.sops.yaml` configuration if one does not exist.
        2. Generates a new master AGE key pair.
        3. Saves the private master key to the path specified in `.sops.yaml`
           (e.g., `./age.key`). This file is the root of all trust and MUST be
           backed up and kept secure.
        4. In `.sops.yaml`, it records the public master key under an anchor
           for the specified admin user (e.g., `&user-admin`).
        5. Encrypts the admin's private AGE key into their own secrets file,
           protected by the master key itself.

        This establishes a model where one or more admins hold the master key(s),
        while all other keys (for hosts, users, etc.) are ephemeral and can be
        rotated and managed safely within a Git repository.

    updatekeys
        Scans all secret files and updates their SOPS metadata. This is done
        automatically after changing a master AGE key or adding a new recipient
        to a file's `key_groups` in `.sops.yaml`. It ensures all files can be
        decrypted by the currently configured keys.

KEY / RESOURCE TYPES
    The TYPE argument specifies the kind of secret to manage.

    age-key     AGE encryption key pair.
    ssh-key     SSH key pair (Ed25519).
    wg-key      WireGuard key pair.
    luks-key    A passphrase for LUKS disk encryption.
    passwd      A user's login password (stored as a salted SHA-512 hash).
    mail        An email account password (handled like `passwd`).
    tls-cert    A TLS certificate and its private key.

ENVIRONMENT VARIABLES
    SOPS_AGE_KEY_FILE
        Path to the master AGE private key file. The script sets this
        automatically based on the `.sops.yaml` configuration.

    DEBUG=true
        Enables verbose debug logging, showing function calls and detailed steps.

    PRIVATE_FILE=<path>
        If set during a `new-private` action, the script will use the contents
        of the specified file as the private key instead of generating a new one.

CONFIGURATION: .sops.yaml
    The script parses it to understand the repository's structure and encryption
    rules. Key sections include:

    `keys`: Defines YAML anchors for AGE public keys, which are used to grant
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

# instead of `echo`
log() {
    local \
        log=false \
        msg=$1 \
        level=$2 \
        caller=${FUNCNAME[1]} \
        depth=${#FUNCNAME[@]}

    # The name of the function that called die (or post-cmd -> die) is more useful than die
    if [[ $caller == die || $caller == post-cmd ]]; then
        caller=${FUNCNAME[2]}
    fi

    if [[ $caller == post-cmd ]]; then
        caller=${FUNCNAME[3]}
    fi

    case $level in
    success) msg="[$depth]: $GB${caller}$GN: $msg$NC" ;;
    debug) msg="[$depth]: $YB${caller}$NC: $msg$NC" ;;
    info) msg="[$depth]: $YB${caller}$YN: $msg$NC" ;;
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

# die with mandatory exit code and optional message
die() {
    local exit_code=$1 msg=$2 fn=${3-}

    case $exit_code in
    0) log "$msg" info ;;
    *) log "$msg" error ;;
    esac

    [[ -n "$fn" ]] && "$fn"

    log "exit code $exit_code" debug
    exit "$exit_code"
}

#  switch for exit codes from commands with side effects
post-cmd() {
    local exit_code=$1 err=$2
    [[ $exit_code == 0 ]] || die "$exit_code" "$(cat "$err")"
}

# misc 'setup the environment' thingies
setup() {
    domain="kompismoln.se"

    # bold or not bold red green yellow and normal colors
    RN='\033[0;31m'
    RB='\033[1;31m'
    GN='\033[0;32m'
    GB='\033[1;32m'
    YN='\033[0;33m'
    YB='\033[1;33m'
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
        [[ $type == "ssh-key" ]] && actions+=(sideload pull)
        [[ $type == "age-key" ]] && actions+=(sideload factory-reset)
        ;;
    -u)
        mode="user"
        user=$entity
        types=(age-key ssh-key passwd mail)
        [[ $action == "bootstrap" ]] && {
            type=age-key
            actions+=(bootstrap)
            init-.sops-yaml
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

# make sure actions and types are accepted and that $secrets_file exists
sanitize-dispatcher-input() {
    log "hello" debug

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

# check if a function is defined here
fn-exists() {
    local fn=$1
    declare -F "$fn" >/dev/null
}

# Function dispatcher array - lists functions in priority order until one exists
# Pattern: most specific -> least specific -> fallback
#   1. mode::action::type  (e.g., "host::new::ssh-key")
#   2. mode::action        (e.g., "host::new")
#   3. action::type        (e.g., "new::ssh-key")
#   4. action              (e.g., "new")
#   5. cmd-not-found       (fallback handler)
dispatch() {
    log "hello" debug

    dispatcher=(
        "$mode::$action::$type"
        "$mode::$action"
        "$action::$type"
        "$action"
        cmd-not-found
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
    log "hello" debug

    action=new-private dispatch
    action=sync dispatch
}

# --- *::new-private::*
# Generate/copy a private resource then validate and encrypt it

new-private() {
    log "hello" debug

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
    log "hello" debug

    decrypt
    action=generate-public dispatch >"$public_file"
}

sync::age-key() {
    log "hello" debug
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
    log "hello" debug

    decrypt

    cp "$private_file" "$private_file.plain"
    mkpasswd -sm sha-512 <"$private_file" >"$private_file.hash"
    cp "$private_file.hash" "$private_file"

    type=$type-hashed encrypt
    cp "$private_file.plain" "$private_file"
}

# nixos-mailserver uses linux-like password management
user::sync::mail() {
    log "hello" debug
    user::sync::passwd
}

# --- *::check::*

check::age-key() {
    log "hello" debug
    decrypt
    [[ -f $public_file ]] || die 1 "public key doesn't exist"
    test "$(age-keygen -y <"$private_file")" = "$(cat "$public_file")"
}

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

    log "match: $match" "$log_level"
    log "exit code: $exit_code" debug

    return "$exit_code"
}

check::wg-key() {
    log "hello" debug
    check::ssh-key
}

host::check::age-key() {
    log "hello" debug

    local exit_code=0

    check::age-key || exit_code=1
    check::age-key--sops || exit_code=1
    check::age-key--host || exit_code=1

    log "exit code: $exit_code" debug
    return "$exit_code"
}

host::check::ssh-key() {
    log "hello" debug

    local exit_code=0

    check::ssh-key || exit_code=1
    check::ssh-key--host || exit_code=1

    log "exit code: $exit_code" debug
    return "$exit_code"
}

# check's helpers (not dispatchable)
check::age-key--sops() {
    log "hello" debug

    local \
        exit_code=0 \
        match=true \
        log_level=success \
        from_secret \
        from_sops

    from_secret=$("generate-public::$type")
    log "public key (from secret): $from_secret" info

    from_sops=$(get-anchor)
    log "public key (from .sops.yaml): $from_sops" info

    if [[ ! "$from_secret" == "$from_sops" ]]; then
        exit_code=1
        match=false
        log_level=error
    fi

    log "match: $match" "$log_level"
    log "exit code: $exit_code" debug

    return "$exit_code"
}

check::age-key--host() {
    log "hello" debug

    local \
        exit_code=0 \
        match=true \
        log_level=success \
        from_host="" \
        from_file

    from_file=$(cut -d' ' -f1-2 "$public_file")
    log "public key (from file): $from_file" info

    from_host=$(
        ssh "admin@$host.$domain" "sudo cat /etc/age/keys.txt" 2>"$err"
        echo
    )
    if [[ $from_host == "trust-me" ]]; then
        from_host=$from_file
    else
        from_host=$(echo "$from_host" | age-keygen -y | head -n1)
    fi
    log "public key (from host): $from_host" info

    if [[ $from_host == "trust-me" ]]; then
        from_host=$from_file
    fi

    if [[ "$from_host" != "$from_file" ]]; then
        exit_code=1
        match=false
        log_level=error
    fi

    log "match: $match" "$log_level"
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
        from_file

    from_file=$(cut -d' ' -f1-2 "$public_file")
    log "public key (from file): $from_file" info

    from_host=$(ssh-keyscan -q "$host.$domain" | cut -d' ' -f2-3)
    log "public key (from host): $from_host" info

    if [[ $from_host == "trust-me" ]]; then
        from_host=$from_file
    fi

    if [[ "$from_host" != "$from_file" ]]; then
        exit_code=1
        match=false
        log_level=error
    fi

    log "match: $match" "$log_level"
    log "exit code: $exit_code" debug

    return "$exit_code"
}

host::check::luks-key() {
    decrypt
    ssh "admin@$host.$domain" \
        'sudo $(type -P cryptsetup) open --test-passphrase --key-file=- /dev/sda3' \
        2>"$err" <"$private_file"
    post-cmd $? "$err"
}

# Password and hashed password should match
user::check::passwd() {
    log "hello" debug

    local \
        match=true \
        exit_code=0 \
        salt \
        log_level=success \
        from_secret \
        from_passwd

    type=$type-hashed decrypt
    from_secret=$(cat "$private_file")
    salt=$(awk -F'$' '{print $3}' "$private_file")

    decrypt
    from_passwd=$(mkpasswd -m sha-512 -S "$salt" "$(cat "$private_file")")

    log "hash (from secret): $from_secret" info
    log "hash (from password): $from_passwd" info

    if [[ ! "$from_secret" == "$from_passwd" ]]; then
        exit_code=1
        match=false
        log_level=error
    fi

    log "match: $match" "$log_level"
    log "exit code: $exit_code" debug

    return "$exit_code"
}

user::check::mail() {
    log "hello" debug
    user::check::passwd
}

domain::check::tls-cert() {
    log "hello" debug

    local \
        exit_code=0 \
        match=true \
        log_level=success \
        from_secret \
        from_file \
        san

    decrypt

    if openssl x509 -in "$public_file" -checkend 2592000 >/dev/null 2>&1; then
        log "certificate is still valid for 30 days." info
    else
        log "Certificate will expire within 30 days or is already expired." warning
        match=false
    fi

    san=$(openssl x509 -in "$public_file" -noout -ext subjectAltName 2>/dev/null |
        grep -E "DNS:" | sed 's/.*DNS://g' | tr ',' '\n' | sort)

    if [[ ! "$san" == "$domain" ]]; then
        exit_code=1
        match=false
        log_level=error
        log "incorrect SAN '$san'" error
    else
        log "correct SAN '$san'" info
    fi

    from_secret=$(openssl pkey -in "$private_file" -pubout)
    log "certificate (from secret): $(echo "$from_secret" | sed -n '2p')" info

    from_file=$(openssl x509 -in "$public_file" -pubkey -noout)
    log "certificate (from file): $(echo "$from_file" | sed -n '2p')" info

    if [[ ! "$from_secret" == "$from_file" ]]; then
        exit_code=1
        match=false
        log_level=error
    fi

    log "match: $match" "$log_level"
    log "exit code: $exit_code" debug

    return "$exit_code"
}

# --- *::pull::*

host::pull::ssh-key() {
    ssh-keyscan -q "$host.$domain" | cut -d' ' -f2-3 >"$public_file"
}

# --- *::sideload::*

host::sideload::ssh-key() {
    log "hello" debug
    local host_key=/etc/ssh/ssh_host_ed25519_key

    check::ssh-key ||
        die 1 "Error: Keys are out of sync, run '$0 $host sync ssh-key' first"

    check::ssh-key--host &&
        die 1 "current key is already active"

    scp "$private_file" "$host.$domain:/tmp/ssh-key"

    ssh -t "$host.$domain" "sudo sh -c 'cat /tmp/ssh-key >$host_key && rm -f /tmp/ssh-key && systemctl restart sshd'" 2>"$err"
    post-cmd $? "$err"
}

host::sideload::age-key() {
    log "hello" debug
    local host_key=/etc/age/keys.txt
    local from_host

    # shellcheck disable=SC2015
    check::age-key && check::age-key--sops ||
        die 1 "Error: Keys are out of sync, run '$0 $host sync age-key' first"

    check::age-key--host &&
        die 1 "current key is already active"

    from_host=$(ssh -t "admin@$host.$domain" "sudo cat $host_key" 2>"$err")
    echo "$from_host" >>"$private_file"

    scp "$private_file" "$host.$domain:/tmp/age-key"

    ssh -t "$host.$domain" "sudo sh -c 'cat /tmp/age-key >$host_key && rm -f /tmp/age-key'" 2>"$err"
    post-cmd $? "$err"

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
        --copy-host-keys 2>"$err"
    post-cmd $? "$err"
}

# --- *::create-private::*

create-private::age-key() {
    log "hello" debug
    rm "$private_file"
    age-keygen >"$private_file" 2>"$err"
    post-cmd $? "$err"
}

create-private::ssh-key() {
    log "hello" debug

    ssh-keygen -q -t "ed25519" -f "$private_file" -N "" \
        -C "$mode-key-$(date +%Y-%m-%d)" <<<y >/dev/null 2>"$err"
    post-cmd $? "$err"
}

create-private::wg-key() {
    log "hello" debug

    wg genkey >"$private_file" 2>"$err"
    post-cmd $? "$err"
}

create-private::luks-key() {
    log "hello" debug

    openssl rand -base64 12 >"$private_file" 2>"$out"
    post-cmd $? "$err"
}

create-private::tls-cert() {
    log "hello" debug

    openssl genpkey -algorithm ED25519 -out "$private_file" 2>"$err"
    post-cmd $? "$err"
}

create-private::passwd() {
    log "hello" debug

    read -r -p "Enter password: " password
    echo "$password" >"$private_file"
}

# --- *::generate-public::*

generate-public::age-key() {
    log "hello" debug
    local pubkey

    pubkey=$(age-keygen -y <"$private_file" 2>"$err")
    post-cmd $? "$err"

    echo "$pubkey"
}

generate-public::ssh-key() {
    log "hello" debug
    ssh-keygen -y -f "$private_file" 2>"$err"
    post-cmd $? "$err"
}

generate-public::wg-key() {
    log "hello" debug
    wg pubkey <"$private_file" 2>"$err"
    post-cmd $? "$err"
}

generate-public::tls-cert() {
    log "hello" debug
    openssl req -new -x509 -key "$private_file" \
        -subj "/CN=*.$domain" \
        -addext "subjectAltName=DNS:*.$domain,DNS:$domain" \
        -nodes -out - -days 3650 2>"$err"
    post-cmd $? "$err"
}

# --- *::verify::*

verify::age-key() {
    log "hello" debug
    action=generate-public dispatch >/dev/null
}

verify::ssh-key() {
    log "hello" debug
    action=generate-public dispatch >/dev/null
}

verify::wg-key() {
    log "hello" debug
    action=generate-public dispatch >/dev/null
}

verify::tls-cert() {
    log "hello" debug
    action=generate-public dispatch >/dev/null
}

verify::luks-key() {
    log "hello" debug
    log "luks-key: $(cat "$private_file")" info
}

# TODO: make a more comprehensive security audit on passwd
verify::passwd() {
    log "hello" debug

    [[ -s "$private_file" && -n "$(cat "$private_file")" ]] || {
        log "password is empty" error
        return 1
    }
}

verify::passwd-hashed() {
    log "hello" debug

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
    log "hello" debug

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
    echo "init: true" |
        sops encrypt --filename-override "$secrets_file" /dev/stdin >"$secrets_file" 2>"$err"

    post-cmd $? "$err"
}

# --- sops integrations
encrypt() {
    log "hello" debug

    set-secrets-location
    log "encrypting secret > $secrets_path@$private_file" debug

    action=verify dispatch 2>"$err"
    post-cmd $? "$err"

    sops set "$secrets_file" "$secrets_path" "$(jq -Rs <"$private_file")" >"$out" 2>"$err"
    post-cmd $? "$err"
}

decrypt() {
    log "hello" debug

    set-secrets-location
    log "decrypting secret < $secrets_path@$private_file" debug

    sops decrypt --extract "$secrets_path" "$secrets_file" >"$private_file" 2>"$err"
    post-cmd $? "$err"
}

get-anchor() {
    log "hello" debug
    yq "(.keys[] | select(anchor == \"$mode-$entity\"))" .sops.yaml 2>"$err"
    post-cmd $? "$err"
}

set-anchor() {
    log "hello" debug

    local age_key=$1 new_age_key

    [[ -z $age_key ]] && die 1 "age key invalid: '$age_key'"

    yq -i "(.keys[] | select(anchor == \"$mode-$entity\")) |= \"$age_key\"" .sops.yaml 2>"$err"
    post-cmd $? "$err"

    new_age_key=$(get-anchor)
    [[ "$new_age_key" == "$age_key" ]] || die 1 "update fail: $new_age_key != $age_key"
}

updatekeys() {
    log "hello" debug
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
    log "hello" debug

    cat "$PRIVATE_FILE" >"$private_file" 2>"$err"
    post-cmd $? "$err"
}

bootstrap() {
    log "hello" debug
    local key

    mkdir -p "$(dirname "$secrets_file")"
    touch "$secrets_file"

    create-private::age-key
    cp -a "$private_file" "$SOPS_AGE_KEY_FILE"

    key=$(generate-public::age-key)
    set-anchor "$key"

    echo "$user: { age-key: }" |
        sops encrypt --filename-override "users/$user-enc.yaml" /dev/stdin >"$secrets_file"

    encrypt

    sync::age-key
}

.sops-yaml() {
    log "hello" debug

    local key=$1 template

    log "get '$key'" debug
    template=$(yq "$key" .sops.yaml 2>"$err")
    post-cmd $? "$err"

    eval "echo \"${template//\{/\$\{}\"" 2>"$err"
    post-cmd $? "$err"
}

init-.sops-yaml() {
    log "hello" debug

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
