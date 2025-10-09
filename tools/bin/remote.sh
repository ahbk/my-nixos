#!/usr/bin/env bash
# shellcheck disable=SC2029
# Yes, we know unescaped variables expand client side

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"

main() {
    domain="kompismoln.se"

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
        user=reverse-tunnel
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

eff() {
    sudo cp "$1" "$tmpdir/asdf"
    sudo rm -f "$1"
    sudo mount --bind "$tmpdir/asdf" "$1"

    echo "Temporary $1 ($tmpdir/asdf) ready. Edit $1 freely."
}
push() {
    rsync -av --ignore-existing --info=NAME,SKIP --partial --progress "$src" "$user"@"$address":"$dest"
}

reset() {
    local extra_files="$tmpdir/extra-files"
    local luks_key="$tmpdir/luks_key"
    local age_key="$extra_files/keys/host-$host"
    local kexec

    install -d -m700 "$(dirname "$age_key")"

    #scp -r "./result/." "root@$address:"

    ./tools/id-entities.sh -h "$host" cat-secret luks-key >"$luks_key" || die 1 "no luks-key"
    ./tools/id-entities.sh -h "$host" cat-secret age-key >"$age_key" || die 1 "no age-key"

    chmod 600 "$age_key"

    log info "luks key prepared: $(cat "$luks_key")"
    log info "age key prepared: $(cat "$age_key")"
    #kexec=$(nix build --print-out-paths .#nixosConfigurations.bootstrap.config.system.build.kexecInstallerTarball)
    kexec=/nix/store/79hazfvf8y0v9d8q7nr5jq8z4by5gdbd-kexec-tarball

    nixos-anywhere \
        --flake ".#$host" \
        --target-host "root@$address" \
        --ssh-option GlobalKnownHostsFile=/dev/null \
        --disk-encryption-keys "/keys/host-$host" "$age_key" \
        --disk-encryption-keys "/luks-key" "$luks_key" \
        --generate-hardware-config nixos-facter hosts/"$host"/facter.json \
        --kexec "$kexec/nixos-kexec-installer-x86_64-linux.tar.gz" \
        --extra-files "$extra_files" \
        --copy-host-keys
}

tunnel() {
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

    ssh "${ssh_opts[@]}" "reverse-tunnel@$host"
}

main "$@"
