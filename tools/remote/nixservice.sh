#!/usr/bin/env bash
# tools/remote/nixservice.sh

main() {
    case $1 in
    build)
        local host=$2
        ;;
    pull)
        local closure=$2
        local build_host=${3:-$BUILD_HOST}
        ;;
    switch)
        local closure=$2
        ;;
    *) exit 1 ;;
    esac
    "$1" "$@"
}

build() {
    nix build "$REPO#nixosConfigurations.$host.config.system.build.toplevel" \
        --print-out-paths --no-link --refresh
}

pull() {
    nix copy --from "$build_host" "$closure"
}

switch() {
    sudo nix-env -p /nix/var/nix/profiles/system --set "$closure"
    sudo "$closure/bin/switch-to-configuration" switch
}

main "$@"
