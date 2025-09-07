#!/usr/bin/env bash
set -euo pipefail

main() {
    case $1 in
    wg-key) ;;
    luks-key | age-key)
        IFS= read -r k1 || exit 1
        IFS= read -r k2 || k2=''
        "$1"
        ;;
    *) exit 1 ;;
    esac
}

decode() {
    echo "$1" | base64 -d
}

luks-key() {
    local dev=$LUKS_DEVICE
    cryptsetup open "$dev" --key-file=<(decode "$k1") --test-passphrase || exit 1
    [[ -n $k2 ]] || exit 0
    cryptsetup luksAddKey "$dev" --key-file=<(decode "$k1") --new-keyfile=<(decode "$k2") &&
        cryptsetup luksRemoveKey "$dev" --key-file=<(decode "$k1")
}

wg-key() {
    ping -c1 -I "$DEVICE" "$HOST"
}

age-key() {
    local key_file=$KEY_FILE

    age-keygen -y <"$key_file" | grep -qxF "$(decode "$k1" | age-keygen -y)" ||
        exit 1

    [[ -n $k2 ]] || exit 0
    decode "$k2" | tail -1 | age-keygen -y || exit 1

    decode "$k2" | tail -1 >>"$key_file"

    if [[ "${2:-}" =~ ^[0-9]+$ ]] && (("$2" > 0)); then
        tail -"$2" "$key_file" >"$key_file.tmp" && mv "$key_file.tmp" "$key_file"
        exit 0
    fi
}

main "$@"
