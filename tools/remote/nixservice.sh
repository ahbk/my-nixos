#!/usr/bin/env bash
# tools/remote/nixservice.sh

main() {
    case $1 in
    build)
        host=$2
        refresh=${3:-}
        ;;
    pull)
        closure=$2
        build_host=${3:-$BUILD_HOST}
        ;;
    switch)
        closure=$2
        ;;
    *) exit 1 ;;
    esac
    "$1" "$@"
}

build() {
    if [[ -n $refresh ]]; then
        rm -r "$HOME/.cache/nix/"*
    fi
    nix build "$REPO#nixosConfigurations.$host.config.system.build.toplevel" \
        --print-out-paths --no-link
}

pull() {
    nix copy --from "$build_host" "$closure"
}

switch() {
    sudo nix-env -p /nix/var/nix/profiles/system --set "$closure"
    sudo "$closure/bin/switch-to-configuration" switch
}

main "$@"
