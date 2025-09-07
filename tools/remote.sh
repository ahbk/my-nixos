#!/usr/bin/env bash
# shellcheck disable=SC2029
# Yes, we know unescaped variables expand client side

set -euo pipefail
shopt -s globstar

. ./tools/lib.sh

main() {
    domain="km"

    case $1 in
    rebuild | login)
        host=$2
        user=${3:-admin}
        address=${4:-"$host.$domain"}
        ;;
    reset)
        host=$2
        user="root"
        address=${3:-"$host.$domain"}
        ;;
    tunnel)
        user=tunnelservice
        host="helsinki.kompismoln.se"
        ;;
    image)
        variant=$2
        ;;
    pull | push)
        user="admin"
        host=$2
        specifier="$user@$host.$domain"
        src=$3
        dest=${4:-"./"}
        ;;
    esac
    "$1"
}

image() {
    nixos-rebuild build-image --flake .#iso --image-variant "$variant"
}

pull() {
    with "$user"
    rsync -av --info=NAME,SKIP --partial --progress "$specifier":"$src" "$dest"
    chmod -R u+w "$dest"
    unwith
}

push() {
    rsync -av --ignore-existing --info=NAME,SKIP --partial --progress "$src" "$user"@"$address":"$dest"
}

rebuild() {
    with "$user"
    local askpass
    [[ "$user" != "root" && "$user" != "buildservice" ]] && askpass="--ask-sudo-password"
    nixos-rebuild switch $askpass --flake "./#$host" --target-host "$user@$address"
    unwith
}

login() {
    with "$user"
    ssh "$user@$address"
    unwith
}

reset() {
    with "admin"

    local extra_files="$tmpdir/extra-files"
    local luks_key="$tmpdir/luks_key"
    local age_key="$extra_files/keys/host-$host"

    install -d -m700 "$(dirname "$age_key")"

    #scp -r "./result/." "root@$address:"

    ./tools/id-entities.sh -h "$host" cat-secret luks-key >"$luks_key" || die 1 "no luks-key"
    ./tools/id-entities.sh -h "$host" cat-secret age-key >"$age_key" || die 1 "no age-key"

    chmod 600 "$age_key"

    log info "luks key prepared: $(cat "$luks_key")"
    log info "age key prepared: $(cat "$age_key")"

    ./tools/anywhere.sh \
        --flake ".#$host" \
        --target-host "root@$address" \
        --ssh-option GlobalKnownHostsFile=/dev/null \
        --disk-encryption-keys /luks-key "$luks_key" \
        --generate-hardware-config nixos-facter hosts/"$host"/facter.json \
        --extra-files "$extra_files" \
        --kexec result/tarball/nixos-image-kexec-25.11.20250731.94def63-x86_64-linux.tar.xz \
        --copy-host-keys

    unwith
}

dirty-ssh() {
    ssh -o StrictHostKeyChecking=no \
        -o GlobalKnownHostsFile=/dev/null \
        -o UserKnownHostsFile=/dev/null
}

switch() {
    nixos-rebuild switch --use-remote-sudo --show-trace --verbose
}

tunnel() {
    with "tunnelservice"
    local ssh_opts=(
        -N
        -T
        -R "0.0.0.0:2602:localhost:22"
        -o "ServerAliveInterval=30"
        -o "ServerAliveCountMax=3"
        -o "ExitOnForwardFailure=yes"
        -o "StrictHostKeyChecking=no"
        -o "UserKnownHostsFile=/dev/null"
        -o "LogLevel=ERROR"
        -o "ConnectTimeout=30"
        -o "TCPKeepAlive=yes"
    )

    ssh "${ssh_opts[@]}" "tunnelservice@$host"
    unwith
}

main "$@"
