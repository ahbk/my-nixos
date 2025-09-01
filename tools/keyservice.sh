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
    echo "$k1" | cryptsetup open --test-passphrase --key-file=- "$dev" || exit 1
    [[ -n $k2 ]] || exit 0
    cryptsetup luksAddKey "$dev" --key-file=<(echo -n "$k1") --new-key-file=<(echo -n "$k2") &&
        cryptsetup luksRemoveKey "$dev" --key-file=<(echo -n "$k1")
}

age-key() {
    local key_file=$KEY_FILE

    echo "$k1" | age-keygen -y || exit 1
    age-keygen -y "$key_file" || exit 1
    [[ "$k1" == "$(cat "$key_file")" ]] || exit 1
    [[ -n $k2 ]] || exit 0
    age-keygen -y <"$k2" || exit 1
    echo "$k2" >"$key_file.tmp" && mv "$key_file.tmp" "$key_file"
}

main "$@"
