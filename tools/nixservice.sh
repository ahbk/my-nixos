#!/usr/bin/env bash
# nixservice.sh

main() {
    case $1 in
    build)
        local host=$2
        ;;
    copy)
        local from=$2
        local closure=$3
        ;;
    switch)
        local build=$2
        ;;
    *) exit 1 ;;
    esac
    "$1" "$@"
}

build() {
    nix build "$REPO#nixosConfigurations.$host.config.system.build.toplevel" \
        --print-out-paths --no-link --refresh
}

copy() {
    nix copy --from "http://$from.km:5000" "$closure"
}

switch() {
    sudo nix-env -p /nix/var/nix/profiles/system --set "$build"
    sudo "$build/bin/switch-to-configuration" switch
}

main "$@"
