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
        - sync:   Decrypts the existing private key from secrets.yaml and uses
                  it to regenerate and overwrite the public key file. This is
                  useful if the public key file is missing or out of date.
        - check:  Compares the public key on disk with one generated on-the-fly
                  from the encrypted private key to ensure they match.

  <type>
        The type of key to manage. Must be one of:
        - ssh-host-key: Manages an Ed25519 SSH host key.
        - wg-key:       Manages a WireGuard private key.

EOF
}

set -uo pipefail
set -x

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

# check uses exit code to communicate mismatch
if [[ $action != check ]]; then
    set -e
fi

# Create a new pair of keys (will overwrite existing)
# If a key type needs special handling, create a specific
# function for that type and it will be called instead.
new() {
    if [[ -z ${PRIVATE_KEY+x} ]]; then
        "create-private-$type"
    else
        cat "$PRIVATE_KEY" >"$private_key"
    fi

    "generate-public-$type" >"$public_key"
    encrypt-private
}

# This overrides `new` when called with type=ssh-host-key
new-ssh-host-key() {
    new

    key=$(ssh-to-age <"$public_key") \
        yq -i "(.keys[] | select(anchor == \"host_$host\")) |= env(key)" .sops.yaml

    sops updatekeys -y "$secrets"
}

# Decrypt existing private file and use it to re-generate the public key
sync() {
    if [[ -z ${PRIVATE_KEY+x} ]]; then
        decrypt-private
    else
        cat "$PRIVATE_KEY" >"$private_key"
    fi
    "generate-public-$type" >"$public_key"
    "encrypt-private"
}

sync-ssh-host-key() {
    sync

    key=$(ssh-to-age <"$public_key") \
        yq -i "(.keys[] | select(anchor == \"host_$host\")) |= env(key)" .sops.yaml

    sops updatekeys -y "$secrets"
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
    check
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
    sops set "$secrets" "[\"$type\"]" "$(jq -Rs <"$private_key")"
}

decrypt-private() {
    sops decrypt --extract "[\"$type\"]" ./hosts/"$host"/secrets.yaml >"$private_key"
}

create-private-ssh-host-key() {
    ssh-keygen -t "ed25519" -f "$private_key" -N "" -C "host-key-$(date +%Y-%m-%d)" <<<y
}

generate-public-ssh-host-key() {
    ssh-keygen -y -f "$private_key"
}

create-private-wg-key() {
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
