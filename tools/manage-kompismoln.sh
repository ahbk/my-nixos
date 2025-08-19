#!/usr/bin/env bash
# shellcheck disable=SC2317

set -uo pipefail
shopt -s globstar

usage() {
    cat <<'EOF'

Usage: manage-kompismoln -h <host> <action> <type>
       manage-kompismoln -u <user> <action> <type>
       manage-kompismoln -d <domain> <action> <type>
       manage-kompismoln updatekeys

actions:      new | sync | fetch | check | sideload | pull | factory-reset
host types:   ssh-key | wg-key | luks-key
user types:   ssh-key | passwd | mail
domain types: tls-cert

EOF
}

usage-full() {
    usage
    cat <<'EOF'
    `manage-kompismoln` manages sops-encrypted secrets (private keys, passwords) and their
    corresponding components (public keys, certificates, password hashes) for
    hosts, users, and domains within a repository. It uses a central .sops.yaml
    file to map entities to their respective file paths and encryption keys.

MODES:
  -h <hostname>
        Acts on the hosts' secrets at 'hosts/<hostname>/secrets.yaml
        ssh-key writes public keys to 'hosts/<hostname>/<type>.pub'.

  -u <username>
        Acts on users' secrets at 'users/<username>-enc.yaml
        `ssh-key` writes public keys 'users/<username>-<type>.pub'.

  -d <domainname>
        Acts on domain related secrets at 'domains/secrets.yaml'.
        `tls-cert` write certificates to 'domains/<domain>-<type>.pem'.

  updatekeys
        Runs `sops updatekeys` on all paths above.
  bootstrap
        Creates a minimal viable .sops.yaml with an admin user with
        an encrypted ssh-key and a private age key.
        Mainly used for automated testing.

ARGUMENTS:
  <action>
        Must be one of:
        - init:     Initializes the secret file for a new host, user, or domain
                    based on creation_rules in .sops.yaml.
                    Mainly used for automated testing.

        - new:      Creates a new secret pair (e.g., key pair, password).
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
        - luks-key: Key for LUKS disk encryption.

        Available for User Mode (-u):
        - ssh-key:  A user's Ed25519 SSH key.
        - passwd:   A user's password. The script will prompt for input.
                    A SHA-512 hashed version is also stored as 'passwd-hashed'.
        - mail:     A user's mail password (behaves identically to 'passwd').

        Available for Domain Mode (-d):
        - tls-cert:

ENVIRONMENT VARIABLES:
  PRIVATE_FILE
        When running the 'new' action, if this variable is set to a file
        path, the script will use the content of that file as the private
        key instead of generating a new one.

EXAMPLES:
  # Create a new SSH key pair for 'server01' and update sops recipients
  manage-kompismoln -h server01 new ssh-key

  # Use an existing private SSH to renew key pair for 'server01' and update
  # sops recipients
  PRIVATE_FILE=./ssh_host_ed25519_key secrets -h server01 new ssh-key

  # Check if all keys for 'server01' (on disk, in sops, on host) match
  manage-kompismoln -h server01 check ssh-key

  # Deploy the verified host key to 'server01'
  manage-kompismoln -h server01 sideload ssh-key

  # Set a new password for user 'jane'
  manage-kompismoln -u jane new passwd

  # A WireGuard public key is outdated; regenerate it from the secret
  manage-kompismoln -h vpn-host sync wg-key

EOF
}

main() {
    setup "$@"

    case $action in
    bootstrap)
        bootstrap
        exit_code=$?
        ;;
    init)
        init
        exit_code=$?
        ;;
    *)
        sanitize-dispatcher-input
        dispatch
        exit_code=$?
        case $exit_code in
        0) log "$mode::$action::$type completed" success ;;
        *) log "$mode::$action::$type completed with errors" error ;;
        esac
        ;;
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
    local \
        exit_code=$1 \
        msg=$2 \
        fn=${3-}

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
    local \
        exit_code=$1 \
        error_msg=${2-} \
        msg=${3-}

    case $exit_code in
    0)
        if [[ -n $msg ]]; then
            log "$msg" success
        fi
        ;;
    *) die "$exit_code" "$error_msg" ;;
    esac
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
        type=${4-"ssh-key"}
        ;;

    --help)
        usage-full
        exit 0
        ;;
    updatekeys)
        updatekeys
        exit 0
        ;;
    factory-reset)
        type=ssh-key
        ;;
    bootstrap)
        mode=-u
        entity="admin"
        user=$entity
        action=bootstrap
        type=ssh-key
        ;;
    *) die 1 "invalid mode: $mode" usage ;;
    esac

    actions=(new new-private sync check)

    case $mode in
    -h)
        mode="host"
        host=$entity
        types=(ssh-key wg-key luks-key)

        if [[ $type == "ssh-key" ]]; then
            actions+=(sideload factory-reset pull)
        fi
        ;;
    -u)
        mode="user"
        user=$entity
        types=(ssh-key passwd mail)
        ;;
    -d)
        mode="domain"
        domain=$entity
        types=(tls-cert)
        ;;
    esac

    if [[ $action == "bootstrap" ]]; then
        init-.sops-yaml
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

    [ -f "$secrets_file" ] ||
        die 1 "no file found in '$secrets_file', did you spell $mode correctly?"
}

# check if a function is defined here
fn-exists() {
    local fn=$1
    declare -F "$fn" >/dev/null
}

# runs when no function is defined for the combination
cmd-not-found() {
    die 127 "no function found for $mode::$action::$type"
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
        fn-exists "$run" && break
    done

    log "$run!" info
    "$run"
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

    if [[ -n ${PRIVATE_FILE+x} ]]; then
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

# SSH keys are also used for encryption so in addition to normal sync we'll
# need to update .sops.yaml.
# TODO: when script is stabilized, update only if anchor differs
sync::ssh-key() {
    log "hello" debug

    sync
    sync::ssh-key--sops

}

sync::ssh-key--sops() {
    local age_key new_age_key

    age_key="$(ssh-to-age <"$public_file")"

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

# Users need to check .sops.yaml as well
user::check::ssh-key() {
    log "hello" debug

    local exit_code=0

    check::ssh-key || exit_code=1
    check::ssh-key--sops || exit_code=1

    log "exit code: $exit_code" debug
    return "$exit_code"
}

# Hosts need to check .sops.yaml like users and also the live host
host::check::ssh-key() {
    log "hello" debug

    local exit_code=0

    check::ssh-key || exit_code=1
    check::ssh-key--sops || exit_code=1
    check::ssh-key--host || exit_code=1

    log "exit code: $exit_code" debug
    return "$exit_code"
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
    post-cmd $? "no match: $(cat "$err")" "match"
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
    sync::ssh-key--sops
}

# --- *::sideload::*

host::sideload::ssh-key() {
    log "hello" debug
    local \
        host_key=/etc/ssh/ssh_host_ed25519_key \
        temp_key=/tmp/newkey

    # shellcheck disable=SC2015
    check::ssh-key && check::ssh-key--sops ||
        die 1 "Error: Keys are out of sync, run '$0 $host sync ssh-key' first"

    check::ssh-key--host &&
        die 1 "current key is already active"

    scp "$private_file" "$host.$domain:$temp_key"

    # shellcheck disable=SC2087
    ssh -t "$host.$domain" 2>"$err" <<EOF
    sudo sh -c '
    chown root:root $temp_key && \
        chmod 600 $temp_key && \
        ln -f $host_key $host_key- && \
        mv -f -T $temp_key $host_key && \
        systemctl restart sshd
    '
EOF

    post-cmd $? "sidoload failed: $(cat "$err")" "sideload succeded"
    log "rebuild $host now or suffer the consequences" warning
}

# --- *::factory-reset::*

host::factory-reset::ssh-key() {
    local extra_files="$tmp/mnt"
    local host_key="$extra_files/etc/ssh/ssh_host_ed25519_key"

    install -d -m755 "$extra_files/etc/ssh"
    decrypt
    cp "$private_file" "$host_key"
    chmod 600 "$host_key"

    type=luks-key decrypt

    nixos-anywhere \
        --flake ".#$host" \
        --target-host root@"$host.$domain" \
        --ssh-option GlobalKnownHostsFile=/dev/null \
        --disk-encryption-keys /secret.key "$private_file" \
        --generate-hardware-config nixos-facter hosts/"$host"/facter.json \
        --extra-files "$extra_files" \
        --copy-host-keys 2>"$err"
    post-cmd $? "failed: $(cat "$err")" "complete"
}

# --- *::create-private::*

create-private::ssh-key() {
    log "hello" debug

    ssh-keygen -q -t "ed25519" -f "$private_file" -N "" \
        -C "$mode-key-$(date +%Y-%m-%d)" <<<y >/dev/null 2>&1
    post-cmd $? "unusual" "private ssh-key $(head -n 1 "$private_file") > $private_file"
}

create-private::wg-key() {
    log "hello" debug

    wg genkey >"$private_file"
    post-cmd $? "unusual" "$private_file generated"
}

create-private::luks-key() {
    log "hello" debug

    openssl rand -base64 12 >"$private_file"
    post-cmd $? "unusual" "$private_file generated"
}

create-private::tls-cert() {
    log "hello" debug

    openssl genpkey -algorithm ED25519 -out "$private_file"
    post-cmd $? "unusual" "$private_file generated"
}

create-private::passwd() {
    log "hello" debug

    read -r -p "Enter password: " password
    echo "$password" >"$private_file"
}

# --- *::generate-public::*

generate-public::ssh-key() {
    log "hello" debug
    local pubkey

    pubkey=$(ssh-keygen -y -f "$private_file")
    post-cmd $? "could not generate from $(head -n 1 "$private_file")" "public key: $pubkey"

    echo "$pubkey"
}

generate-public::wg-key() {
    log "hello" debug
    wg pubkey <"$private_file"
    post-cmd $? "unusual" "$private_file generated"
}

generate-public::tls-cert() {
    log "hello" debug
    openssl req -new -x509 -key "$private_file" \
        -subj "/CN=*.$domain" \
        -addext "subjectAltName=DNS:*.$domain,DNS:$domain" \
        -nodes -out - -days 3650
    post-cmd $? "unusual" "$private_file generated"
}

# --- *::verify::*

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

    post-cmd $? "creating secrets failed: $(cat "$err")" "secrets file created"
}

# --- sops integrations
encrypt() {
    log "hello" debug

    set-secrets-location
    log "encrypting secret > $secrets_path@$private_file" debug

    action=verify dispatch
    post-cmd $? "verification failed" "secret verified"

    sops set "$secrets_file" "$secrets_path" "$(jq -Rs <"$private_file")" >"$out" 2>"$err"
    post-cmd $? "encryption failed: $(cat "$err")" "secret encrypted: $(cat "$out")"
}

decrypt() {
    log "hello" debug

    set-secrets-location
    log "decrypting secret < $secrets_path@$private_file" debug

    sops decrypt --extract "$secrets_path" "$secrets_file" >"$private_file" 2>"$err"
    post-cmd $? "something seems wrong with $secrets_file: $(cat "$err")" "secret decrypted"
}

get-anchor() {
    log "hello" debug
    local key

    key=$(yq "(.keys[] | select(anchor == \"$mode-$entity\"))" .sops.yaml 2>"$err")
    post-cmd $? "$(cat "$err")" "got: $key"
    echo "$key"
}

set-anchor() {
    log "hello" debug

    local age_key=$1 new_age_key

    [[ -z $age_key ]] && die 1 "age key invalid: '$age_key'"

    yq -i "(.keys[] | select(anchor == \"$mode-$entity\")) |= \"$age_key\"" .sops.yaml
    post-cmd $? "err" "out"

    new_age_key=$(get-anchor)
    post-cmd $? "err" "out"

    [[ "$new_age_key" == "$age_key" ]] || die 1 "update fail: $new_age_key != $age_key"
}

updatekeys() {
    log "hello" debug

    if [[ -d "./users" ]]; then
        log "<users>" info
        sops updatekeys -y users/*-enc.yaml 2>"$err"
        post-cmd $? "fail" "</users>"
    fi

    if [[ -d "./hosts" ]]; then
        log "<hosts>" info
        sops updatekeys -y hosts/**/secrets.yaml >"$out" 2>"$err"
        post-cmd $? "<$err" "</hosts>"
    fi

    if [[ -d "./domains" ]]; then
        log "<domains>" info
        sops updatekeys -y domains/*-enc.yaml
        post-cmd $? "fail" "</domains>"
    fi
}

# --- misc helpers

set-secrets-location() {
    IFS=" " read -r secrets_path secrets_file <<<"$(.sops-yaml ".$mode-secrets")"
}

copy-private() {
    log "hello" debug

    cat "$PRIVATE_FILE" >"$private_file"
    post-cmd $? "could not read file" "copied $PRIVATE_FILE to $private_file"
}

bootstrap() {
    log "hello" debug
    local key

    create-private::ssh-key
    ssh-to-age -private-key -i "$private_file" >"$SOPS_AGE_KEY_FILE"

    key=$(generate-public::ssh-key | ssh-to-age)
    set-anchor "$key"

    mkdir -p "$(dirname "$secrets_file")"

    echo "$user: { ssh-key: }" |
        sops encrypt --filename-override users/admin-enc.yaml /dev/stdin >"$secrets_file"

    encrypt

    sync::ssh-key
}

.sops-yaml() {
    log "hello" debug

    local key=$1 template value

    log "get '$key'" debug
    template=$(yq "$key" .sops.yaml 2>"$err")
    post-cmd $? "$(cat "$err")"

    value=$(eval "echo \"${template//\{/\$\{}\"" 2>"$err")
    post-cmd $? "$(cat "$err")" "$key: $value"

    echo "$value"
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
domain-secrets: "['{domain}']['{type}'] domains/secrets.yaml"

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
