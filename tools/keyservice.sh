#!/usr/bin/env bash
set -euo pipefail

main() {
    case $1 in
    luks-key | age-key)
        IFS= read -rs k1 || k1=""
        IFS= read -rs k2 || k2=""
        $1
        ;;
    *) exit 1 ;;
    esac
}

luks-key() {
    local dev=$LUKS_DEVICE
    cryptsetup open "$dev" --key-file=<(echo "$k1") --test-passphrase || exit 1
    [[ -n $k2 ]] || exit 0
    cryptsetup luksAddKey "$dev" --key-file=<(echo "$k1") --new-keyfile=<(echo "$k2") &&
        cryptsetup luksRemoveKey "$dev" --key-file=<(echo "$k1")
}

age-key() {
    local key_file=$KEY_FILE

    echo "$k1" | age-keygen -y || exit 1
    tail -1 "$key_file" | age-keygen -y || exit 1

    [[ "$k1" == "$(tail -1 "$key_file")" ]] || exit 12

    [[ -n $k2 ]] || exit 0

    echo "$k2" | age-keygen -y || exit 1
    echo "$k2" >>"$key_file"

    if [[ "${2:-}" =~ ^[0-9]+$ ]] && (("$2" > 0)); then
        tail -"$2" "$key_file" >"$key_file.tmp" && mv "$key_file.tmp" "$key_file"
        exit 0
    fi
}

main "$@"
