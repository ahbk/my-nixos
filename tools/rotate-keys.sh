#!/usr/bin/env bash
usage() {
    cat <<'EOF'

    
Usage: rotate-keys <host> <action> <type>

Manages encrypted private keys (using sops) and their corresponding public keys for different hosts.

ARGUMENTS:
  <host>
        The target host identifier. This is used to find the corresponding
        secret file at 'hosts/<host>/secrets.yaml'.

  <action>
        The operation to perform. Must be one of:
        - new:    Creates a new private/public key pair. The private key is
                  encrypted into the host's secrets.yaml file, and the
                  public key is saved to 'keys/<host>-<type>.pub'.
                  This will overwrite existing keys.

                  If $PRIVATE_KEY is set it will be used instead of generating
                  a new key.

        - sync:   Decrypts the existing private key from secrets.yaml and uses
                  it to regenerate and overwrite the public key file. This is
                  useful if the public key file is missing or out of date.
                  This will overwrite existing keys.

        - check:  Compares the public key on disk with one generated on-the-fly
                  from the encrypted private key to ensure they match.

        - deploy: Deploys the private key from secrets.yaml to the target host.
                  This copies the decrypted private key to the host via scp/ssh
                  using sudo privileges. Only available for ssh-host-key type.


  <type>
        The type of key to manage. Must be one of:
        - ssh-host-key: Manages a pair of Ed25519 SSH host keys.
        - wg-key:       Manages a pair of WireGuard private key.

EOF
}

set -uo pipefail
#set -x
#set -e
script_path="$(dirname "${BASH_SOURCE[0]}")"

RED='\033[0;31m'
BOLD_RED='\033[1;31m'
YELLOW='\033[0;33m'
BOLD_YELLOW='\033[1;33m'
GREEN='\033[0;31m'
BOLD_GREEN='\033[1;32m'
NC='\033[0m' # No Color

die() {
    echo ""
    echo -e "${BOLD_RED}Error:${RED} $1" >&2
    echo ""
    exit 1
}

if [[ $# != 3 ]]; then
    usage
    die "3 arguments required."
fi

private_key=$(mktemp)
trap 'rm -f "$private_key"' EXIT

host=$1
action=$2
type=$3

secrets="hosts/$host/secrets.yaml"
public_key="keys/$host-$type.pub"
actions=(new sync check deploy new-private)
types=(ssh-host-key wg-key)

if [ ! -d "$(dirname "$secrets")" ]; then
    die "hostname '$host' doesn't have an entry in hosts/, did you spell it correctly?"
fi

if [[ ! " ${actions[*]} " =~ " $action " ]]; then
    die "'$action' is not an action. Allowed actions: ${actions[*]} $(usage)" >&2
fi

if [[ ! " ${types[*]} " =~ " $type " ]]; then
    die "'$type' is not a valid key type. Allowed key types: ${types[*]} $(usage)" >&2
fi

if [ ! -f "$secrets" ]; then
    echo -e "${BOLD_YELLOW}Notice: ${YELLOW}hostname '$host' doesn't have a secrets.yaml yet, creating...${NC}"
    sops encrypt "$script_path/secrets.template.yaml" >"$secrets"
fi

# Dispatch to the correct function
# e.g. rotate-keys helsinki check ssh-host-key -> 1) check-ssh-host-key or 2) check
main() {
    if declare -F "$action-$type" >/dev/null 2>&1; then
        fn="$action-$type"
    elif declare -F "$action" >/dev/null 2>&1; then
        fn="$action"
    else
        usage
        exit 1
    fi
    $fn
    echo ""
    echo -e "${BOLD_GREEN}Rotation completed.${NC}"
}

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
# --- Dispatcher functions ---

# Create a new pair of keys (will overwrite existing)
# If a key type needs special handling, create a specific
# function for that type and it will be called instead.
new() {
    new-private
    "generate-public-$type" >"$public_key"
}

# This overrides `new` when called with type=ssh-host-key
new-ssh-host-key() {
    new

    key="$(ssh-to-age <"$public_key")"
    yq -i "(.keys[] | select(anchor == \"host_$host\")) |= \"$key\"" .sops.yaml

    same_key=$(yq "(.keys[] | select(anchor == \"host_$host\"))" .sops.yaml)

    if [[ "$key" != "$same_key" ]]; then
        die "anchor 'host_$host' not updated"
    fi

    update-sops
}

new-private() {
    if [[ -z ${PRIVATE_KEY+x} ]]; then
        "create-private-$type"
    else
        copy-private
    fi
    encrypt-private
}

# Decrypt existing private file and use it to re-generate the public key
sync() {
    decrypt-private
    "generate-public-$type" >"$public_key"
}

sync-ssh-host-key() {
    sync

    key=$(ssh-to-age <"$public_key") \
        yq -i "(.keys[] | select(anchor == \"host_$host\")) |= env(key)" .sops.yaml

    update-sops
}

deploy-ssh-host-key() {

    if ! check || ! check-ssh-host-key-sops; then
        echo ""
        echo "Error: Keys are out of sync, run '$0 $host sync ssh-host-key' first" >&2
        exit 1
    fi

    if check-ssh-host-key-host; then
        echo ""
        echo "Error: Current key is already deployed" >&2
        exit 1
    fi

    scp "$private_key" "$host.kompismoln.se:pk"
    scp "$script_path/deploy-ssh-host-key.sh" "$host.kompismoln.se:"

    ssh -t "$host.kompismoln.se" "
        chmod +x deploy-ssh-host-key.sh
        sudo ./deploy-ssh-host-key.sh
        rm -f ./pk
        rm -f ./deploy-ssh-host-key.sh
    "
}

check() {
    decrypt-private
    local exit_code=0
    echo ""

    from_encryption=$("generate-public-$type")
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

check-ssh-host-key() {
    local exit_code=0
    set +e
    check || exit_code=1
    check-ssh-host-key-sops || exit_code=1
    check-ssh-host-key-host || exit_code=1
    set -e

    echo ""
    echo "exit code: $exit_code"
    return $exit_code
}

check-ssh-host-key-sops() {
    echo ""

    from_encryption=$(ssh-to-age <<<"$("generate-public-$type")")
    echo "Age key from encryption:"
    echo "$from_encryption"

    from_sops=$(yq "(.keys[] | select(anchor == \"host_$host\"))" .sops.yaml)
    echo "Age key from sops:"
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

check-ssh-host-key-host() {
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

encrypt-private() {
    echo "Encrypt private key '$type' in $secrets"
    sops set "$secrets" "[\"$type\"]" "$(jq -Rs <"$private_key")"
}

decrypt-private() {
    echo "Decrypt private key '$type' from $secrets"
    sops decrypt --extract "[\"$type\"]" ./hosts/"$host"/secrets.yaml >"$private_key"

    try "private key invalid" ssh-keygen -l -f "$private_key" >/dev/null
}

copy-private() {
    echo "Copy private key to $private_key"

    local content
    if [[ ! -f $PRIVATE_KEY ]]; then die "'$PRIVATE_KEY' is not a file."; fi
    content=$(sudo cat "$PRIVATE_KEY")
    echo "$content" >"$private_key"

    try "private key invalid" ssh-keygen -l -f "$private_key" >/dev/null
}

create-private-ssh-host-key() {
    echo "Create private key at $private_key"
    ssh-keygen -q -t "ed25519" -f "$private_key" -N "" -C "host-key-$(date +%Y-%m-%d)" <<<y >/dev/null 2>&1
}

generate-public-ssh-host-key() {
    ssh-keygen -y -f "$private_key"
}

create-private-wg-key() {
    echo "Create private key at $private_key"
    wg genkey >"$private_key"
}

generate-public-wg-key() {
    wg pubkey <"$private_key"
}

update-sops() {
    echo ""
    echo "Updating secrets with new keys:"
    sops updatekeys -y "$secrets"
    sops updatekeys -y "secrets/users.yaml"
    echo ""
    echo -e "${BOLD_GREEN}Keys updated."
}

main "$@"
