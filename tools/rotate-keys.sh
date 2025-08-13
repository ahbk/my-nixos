#!/usr/bin/env bash
usage() {
    cat <<'EOF'

Usage: rotate-keys -h <host> <action> <type>
       rotate-keys -u <user> <action> <type>
       rotate-keys -d <domain> <action> <type>

actions:      new | sync | check | deploy
host types:   ssh-key | wg-key
user types:   ssh-key | passwd | mail
domain types: tls-cert

EOF
}

usage-full() {
    usage
    cat <<'EOF'
Manages sops-encrypted secrets (private keys, passwords) and their corresponding
public components for hosts and users within the repository.

MODES:
  -h <hostname>
        Operates in 'host' mode. Targets a specific host.
        Secrets are expected at 'hosts/<hostname>/secrets.yaml'.
        Public keys are stored at 'hosts/<hostname>/<type>.pub'.

  -u <username>
        Operates in 'user' mode. Targets a specific user.
        Secrets are expected at 'users/<username>-enc.yaml'.
        Public keys are stored at 'users/<username>-<type>.pub'.

  -d <domainname>
        Operates in 'domain' mode. Targets a specific domain.
        Secrets are expected at 'domains/<domainname>-enc.yaml'.
        Certificates are stored at 'domains/<domain>-tls-cert.pem'.

ARGUMENTS:
  <action>
        The operation to perform. Must be one of:

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

        - deploy:   [Host Mode, ssh-key only] Deploys the decrypted private
                    SSH key to the target host's '/etc/ssh/' directory via scp/ssh.
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
  PRIVATE_KEY
        When running the 'new' action, if this variable is set to a file
        path, the script will use the content of that file as the private
        key instead of generating a new one.

EXAMPLES:
  # Create a new SSH key pair for 'server01' and update sops recipients
  rotate-keys -h server01 new ssh-key

  # Use an existing private SSH to renew key pair for 'server01' and update
  # sops recipients
  PRIVATE_KEY=./ssh_host_ed25519_key rotate-keys -h server01 new ssh-key

  # Check if all keys for 'server01' (on disk, in sops, on host) match
  rotate-keys -h server01 check ssh-key

  # Deploy the verified host key to 'server01'
  rotate-keys -h server01 deploy ssh-key

  # Set a new password for user 'jane'
  rotate-keys -u jane new passwd

  # A WireGuard public key is outdated; regenerate it from the secret
  rotate-keys -h vpn-host sync wg-key

EOF
}

set -uo pipefail
shopt -s globstar
#set -x
script_path="$(dirname "${BASH_SOURCE[0]}")"

RN='\033[0;31m'
RB='\033[1;31m'
GN='\033[0;32m'
GB='\033[1;32m'
YN='\033[0;33m'
YB='\033[1;33m'
NC='\033[0m'

try() {
    local msg=$1
    shift
    local output
    local exit_code

    output=$("$@" 2>&1)
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        if [ -n "$output" ]; then
            die "$msg (exit $exit_code): $output"
        else
            die "$msg (exit $exit_code)"
        fi
    fi
}

die() {
    echo ""
    echo -e "${RB}Error:${RN} $1${NC}" >&2
    echo ""
    [[ -n ${2+x} ]] && $2
    exit 1
}

case $1 in
-h | -u | -d)
    mode=$1
    shift
    ;;
--help)
    usage-full
    exit 0
    ;;
*) die "invalid flag: $1" usage ;;
esac

if [[ $# != 3 ]]; then
    die "wrong number of arguments provided." usage
fi

private_key=$(mktemp)
trap 'rm -f "$private_key"' EXIT

entity=$1 # The name of the host/user/domain entity
action=$2
type=$3

case $mode in
-h)
    mode="host"
    host=$1
    secrets="hosts/$host/secrets.yaml"
    public_key="hosts/$host/$type.pub"
    actions=(new sync check deploy new-private)
    types=(ssh-key wg-key)
    ;;
-u)
    mode="user"
    user=$1
    secrets="users/$user-enc.yaml"
    public_key="users/$user-$type.pub"
    actions=(new sync check)
    types=(ssh-key passwd mail)
    ;;
-d)
    mode="domain"
    domain=$1
    secrets="domains/$domain-enc.yaml"
    public_key="domains/$domain-$type.pem"
    actions=(new sync check)
    types=(tls-cert)
    ;;
esac

if [[ ! " ${actions[*]} " =~ " $action " ]]; then
    die "'$action' is not an action. Allowed actions: ${actions[*]}" usage
fi

if [[ ! " ${types[*]} " =~ " $type " ]]; then
    die "'$type' is not a valid key type. Allowed key types: ${types[*]}" usage
fi

if [ ! -f "$secrets" ]; then
    die "no file found in '$secrets' did you spell $mode correctly?"
fi

# Dispatch to the correct function
# Navigate this script by searching for the action followed by (
# e.g. 'check(', all overrides are found bellow it.
#
main() {
    for fn in \
        "$mode::$action::$type" \
        "$mode::$action" \
        "$action::$type" \
        "$action"; do
        if declare -F "$fn" >/dev/null; then
            break
        fi
        fn=""
    done

    [ -n "$fn" ] || die "no function found for $mode::$action::$type"

    $fn
    exit_code=$?

    echo ""
    echo -e "${GB}$action completed."

    if [[ $exit_code == 0 ]]; then
        echo -e "${GN}exit code: $exit_code"
    else
        echo -e "${RN}exit code: $exit_code"
    fi
}
# --- Dispatcher functions ---

# Create a new pair of keys (will overwrite existing)
# If a key type needs special handling, create a specific
# function for that type and it will be called instead.
new() {
    new-private
    "generate-public::$type" >"$public_key"
}

# This overrides `new` when called with type=ssh-key
new::ssh-key() {
    new

    local key current_key

    current_key=$(yq "(.keys[] | select(anchor == \"$mode-$entity\"))" .sops.yaml)

    if [[ -z $current_key ]]; then
        die "anchor '$mode-$entity' missing in .sops.yaml, add it and run again."
    fi

    key="$(ssh-to-age <"$public_key")"
    yq -i "(.keys[] | select(anchor == \"$mode-$entity\")) |= \"$key\"" .sops.yaml

    current_key=$(yq "(.keys[] | select(anchor == \"$mode-$entity\"))" .sops.yaml)

    if [[ "$key" != "$current_key" ]]; then
        die "anchor '$mode-$entity' not updated"
    fi

    update-sops
}

user::new::passwd() {
    read -r -p "Enter password: " password
    encrypt::passwd "$password"
}

user::new::mail() {
    user::new::passwd
}

new-private() {
    if [[ -n ${PRIVATE_KEY+x} ]]; then
        copy-private
    else
        "create-private::$type"
    fi
    encrypt "$(cat "$private_key")"
}

# Decrypt existing private file and use it to re-generate the public key
sync() {
    decrypt
    "generate-public::$type" >"$public_key"
}

sync::ssh-key() {
    sync

    key=$(ssh-to-age <"$public_key") \
        yq -i "(.keys[] | select(anchor == \"host_$host\")) |= env(key)" .sops.yaml

    update-sops
}

user::sync::passwd() {
    local hash salt

    if user::check::passwd; then
        echo "Already in sync"
        return 0
    fi

    type=$type-hashed decrypt
    hash=$(cat "$private_key")
    salt=$(awk -F'$' '{print $3}' "$private_key")

    decrypt
    encrypt::passwd "$(cat "$private_key")" "$salt"
}

user::sync::mail() {
    user::sync::passwd
}

check() {
    decrypt
    local exit_code=0
    echo ""

    from_encryption=$("generate-public::$type")
    echo "Key from encryption:"
    echo "$from_encryption"

    [[ -f $public_key ]] || die "public key doesn't exist"
    from_file=$(<"$public_key")
    echo "Key from file:"
    echo "${from_file:-[empty]}"

    match=true
    if [[ ! "$from_encryption" == "$from_file" ]]; then
        exit_code=1
        match=false
    fi
    echo "Match: $match"

    return $exit_code
}

user::check::ssh-key() {
    local exit_code=0

    check || exit_code=1
    check::ssh-key--sops || exit_code=1

    echo ""
    echo "exit code: $exit_code"
    return $exit_code
}

host::check::ssh-key() {
    local exit_code=0

    check || exit_code=1
    check::ssh-key--sops || exit_code=1
    check::ssh-key--host || exit_code=1

    echo ""
    echo "exit code: $exit_code"
    return $exit_code
}

user::check::passwd() {
    local \
        match=true \
        exit_code=0 \
        salt \
        hash \
        expected_hash

    type=$type-hashed decrypt
    hash=$(cat "$private_key")
    salt=$(awk -F'$' '{print $3}' "$private_key")

    decrypt
    expected_hash=$(mkpasswd -m sha-512 -S "$salt" "$(cat "$private_key")")

    echo ""
    echo "Expected hash:"
    echo "$expected_hash"
    echo "Actual hash:"
    echo "$hash"

    if [[ ! "$expected_hash" == "$hash" ]]; then
        exit_code=1
        match=false
    fi

    echo ""
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

    echo ""
    if openssl x509 -in "$public_key" -checkend 2592000 >/dev/null 2>&1; then
        echo "Certificate is still valid for 30 days."
    else
        echo "Certificate will expire within 30 days or is already expired."
        match=false
    fi

    san_from_cert=$(openssl x509 -in "$public_key" -noout -ext subjectAltName 2>/dev/null |
        grep -E "DNS:" | sed 's/.*DNS://g' | tr ',' '\n' | sort)

    echo ""
    echo "Expected SAN:"
    echo "$domain"
    echo "Certificate SAN:"
    echo "$san_from_cert"

    if [[ ! "$san_from_cert" == "$domain" ]]; then
        exit_code=1
        match=false
    fi

    echo ""
    private_pubkey=$(openssl pkey -in "$private_key" -pubout)
    echo "Private public key:"
    echo "$private_pubkey"

    echo ""
    cert_pubkey=$(openssl x509 -in "$public_key" -pubkey -noout)
    echo "Certificate public key:"
    echo "$cert_pubkey"

    if [[ ! "$cert_pubkey" == "$private_pubkey" ]]; then
        exit_code=1
        match=false
    fi

    echo ""
    if [[ $exit_code == 0 ]]; then
        echo -e "${GB}Match: ${GN}$match${NC}"
    else
        echo -e "${RB}Match: ${RN}$match${NC}"
    fi

    return $exit_code
}

check::ssh-key--sops() {
    echo ""

    from_encryption=$(ssh-to-age <<<"$("generate-public::$type")")
    echo "Age key from encryption:"
    echo "$from_encryption"

    from_sops=$(yq "(.keys[] | select(anchor == \"$mode-$entity\"))" .sops.yaml)
    echo "Age key from sops ($mode-$entity):"
    echo "$from_sops"

    match=true
    local exit_code=0
    if [[ ! "$from_encryption" == "$from_sops" ]]; then
        match=false
        exit_code=1
    fi
    echo "Match (.sops.yaml): $match"

    return "$exit_code"
}

check::ssh-key--host() {
    echo ""

    from_host=$(ssh-keyscan -q "$host.kompismoln.se" | cut -d' ' -f2-3)
    echo "From host with ssh-keyscan:"
    echo "$from_host"

    from_file=$(cut -d' ' -f1-2 "$public_key")
    echo "From file without comment"
    echo "$from_file"

    match=true
    local exit_code=0
    if [[ ! "$from_host" == "$from_file" ]]; then
        match=false
        exit_code=1
    fi
    echo "Match (host): $match"

    return "$exit_code"
}

deploy::ssh-key() {

    if ! check || ! check::ssh-key--sops; then
        echo ""
        echo "Error: Keys are out of sync, run '$0 $host sync ssh-key' first" >&2
        exit 1
    fi

    if check::ssh-key--host; then
        echo ""
        echo "Error: Current key is already deployed" >&2
        exit 1
    fi

    scp "$private_key" "$host.kompismoln.se:pk"
    scp "$script_path/deploy-ssh-key.sh" "$host.kompismoln.se:"

    ssh -t "$host.kompismoln.se" "
        chmod +x deploy-ssh-key.sh
        sudo ./deploy-ssh-key.sh
        rm -f ./pk
        rm -f ./deploy-ssh-key.sh
    "
}

encrypt() {
    echo "Encrypt secret '$type' in $secrets"

    # sops-nix conflates all secrets so non host related secrets need to be
    # prefixed with entity name (have a look at users/*-enc.yaml)
    local path
    path="[\"$type\"]"
    [[ ! $mode == "host" ]] && path="[\"$entity\"]$path"

    try "something seems wrong with $secrets" \
        sops set "$secrets" "$path" "$(jq -Rs <<<"$1")"
}

encrypt::passwd() {
    encrypt "$1"
    local hash
    if [[ $# -ge 2 && -n "$2" ]]; then
        hash=$(mkpasswd -sm sha-512 -S "$2" <<<"$1")
    else
        hash=$(mkpasswd -sm sha-512 <<<"$1")
    fi
    type=$type-hashed encrypt "$hash"
}

decrypt() {
    echo "Decrypt private key '$type' from $secrets"

    # sops-nix conflates all secrets so non host related secrets need to be
    # prefixed with entity name (have a look at users/*-enc.yaml)
    local path exit_code
    path="[\"$type\"]"
    [[ ! $mode == "host" ]] && path="[\"$entity\"]$path"

    sops decrypt --extract "$path" "$secrets" >"$private_key" 2>"$private_key.err"

    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        die "something seems wrong with $secrets: $(cat "$private_key.err")" >&2
    fi
}

copy-private() {
    echo "Copy private key to $private_key"

    local content
    if [[ ! -f $PRIVATE_KEY ]]; then die "'$PRIVATE_KEY' is not a file."; fi
    content=$(sudo cat "$PRIVATE_KEY")
    echo "$content" >"$private_key"

    try "private key invalid" ssh-keygen -l -f "$private_key" >/dev/null
}

create-private::ssh-key() {
    echo "Create private key at $private_key"
    ssh-keygen -q -t "ed25519" -f "$private_key" -N "" \
        -C "$mode-key-$(date +%Y-%m-%d)" <<<y >/dev/null 2>&1
}

create-private::wg-key() {
    echo "Create private key at $private_key"
    wg genkey >"$private_key"
}

create-private::tls-cert() {
    echo "Create TLS private key at $private_key"
    openssl genpkey -algorithm ED25519 -out "$private_key"
}

generate-public::ssh-key() {
    ssh-keygen -y -f "$private_key"
}

generate-public::wg-key() {
    wg pubkey <"$private_key"
}

generate-public::tls-cert() {
    openssl req -new -x509 -key "$private_key" \
        -subj "/CN=*.km" \
        -addext "subjectAltName=DNS:*.km,DNS:km" \
        -nodes -out - -days 3650
}

update-sops() {
    echo ""
    echo "Updating secrets with new keys:"
    sops updatekeys -y hosts/**/secrets.yaml
    sops updatekeys -y users/*-enc.yaml
    echo ""
    echo -e "${GB}Keys updated."
}

main "$@"
