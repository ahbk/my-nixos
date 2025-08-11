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
        - ssh-host-key: Manages an Ed25519 SSH host key.
        - wg-key:       Manages a WireGuard private key.

EOF
}

set -uo pipefail
#set -x
script_path="$(dirname "${BASH_SOURCE[0]}")"

if [[ $# != 3 ]]; then
    usage
    exit 1
fi

private_key=$(mktemp)
trap 'rm -f "$private_key"' EXIT

host=$1
action=$2
type=$3

secrets="hosts/$host/secrets.yaml"
public_key="keys/$host-$type.pub"
actions=(new sync check deploy)

if [ ! -d "$(dirname "$secrets")" ]; then
    echo "Error: hostname '$host' doesn't exist, did you spell it correctly?"
    exit 1
fi

if [[ ! " ${actions[*]} " =~ " $action " ]]; then
    echo "Error: '$action' is not an action. Allowed actions: ${actions[*]}" >&2
    usage
    exit 1
fi

if [ ! -f "$secrets" ]; then
    echo "Notice: hostname '$host' doesn't have a secrets.yaml yet, creating..."
    sops encrypt "$script_path/secrets.template.yaml" >"$secrets"
fi

# Create a new pair of keys (will overwrite existing)
# If a key type needs special handling, create a specific
# function for that type and it will be called instead.
new() {
    if [[ -z ${PRIVATE_KEY+x} ]]; then
        "create-private-$type"
    else
        copy-private
    fi

    "generate-public-$type" >"$public_key"
    encrypt-private
}

# This overrides `new` when called with type=ssh-host-key
new-ssh-host-key() {
    if [[ -z ${PRIVATE_KEY+x} ]]; then
        create-private-ssh-host-key
    else
        copy-private
    fi

    generate-public-ssh-host-key >"$public_key"

    key=$(ssh-to-age <"$public_key") \
        yq -i "(.keys[] | select(anchor == \"host_$host\")) |= env(key)" .sops.yaml

    encrypt-private
    sops updatekeys -y "$secrets"
}

# Decrypt existing private file and use it to re-generate the public key
sync() {
    decrypt-private
    "generate-public-$type" >"$public_key"
    "encrypt-private"
}

sync-ssh-host-key() {
    sync

    key=$(ssh-to-age <"$public_key") \
        yq -i "(.keys[] | select(anchor == \"host_$host\")) |= env(key)" .sops.yaml

    sops updatekeys -y "$secrets"
}

deploy-ssh-host-key() {
    decrypt-private

    temp_key=$(ssh "$host.kompismoln.se" "mktemp")
    scp "$private_key" "$host.kompismoln.se:$temp_key"

    ssh -t "$host.kompismoln.se" "
        sudo cp /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key- &&
        sudo cp '$temp_key' /etc/ssh/ssh_host_ed25519_key &&
        sudo chmod 600 /etc/ssh/ssh_host_ed25519_key &&
        sudo chown root:root /etc/ssh/ssh_host_ed25519_key &&
        rm '$temp_key' &&
        sudo systemctl restart sshd
    "
}

check() {
    decrypt-private

    from_encryption=$("generate-public-$type")
    echo "Key from encryption:"
    echo "$from_encryption"

    from_file=$(<"$public_key")
    echo "Key from file:"
    echo "$from_file"

    if [[ "$from_encryption" == "$from_file" ]]; then
        match=true
        exit_code=0
    else
        match=false
        exit_code=1
    fi

    echo "Match: $match"
    return $exit_code
}

check-ssh-host-key() {
    check || true
    exit_code="$?"
    echo ""

    from_encryption=$(ssh-to-age <<<"$("generate-public-$type")")
    echo "Age key from encryption:"
    echo "$from_encryption"

    from_sops=$(yq "(.keys[] | select(anchor == \"host_$host\"))" .sops.yaml)
    echo "Age key from sops:"
    echo "$from_sops"

    if [[ "$from_encryption" == "$from_sops" ]]; then
        match=true
    else
        match=false
        exit_code=1
    fi

    echo "Match (.sops.yaml): $match"
    return $exit_code
}

encrypt-private() {
    echo "Encrypt private key '$type' in $secrets"
    sops set "$secrets" "[\"$type\"]" "$(jq -Rs <"$private_key")"
}

decrypt-private() {
    echo "Decrypt private key '$type' in $secrets"
    sops decrypt --extract "[\"$type\"]" ./hosts/"$host"/secrets.yaml >"$private_key"
}

copy-private() {
    echo "Copy private key to $private_key"
    cat "$PRIVATE_KEY" >"$private_key"
}

create-private-ssh-host-key() {
    echo "Create private key at $private_key"
    yes | ssh-keygen -q -t "ed25519" -f "$private_key" -N "" -C "host-key-$(date +%Y-%m-%d)" >/dev/null 2>&1
    cat "$private_key"
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

if declare -F "$action-$type" >/dev/null 2>&1; then
    fn="$action-$type"
elif declare -F "$action" >/dev/null 2>&1; then
    fn="$action"
else
    usage
    exit 1
fi

$fn
