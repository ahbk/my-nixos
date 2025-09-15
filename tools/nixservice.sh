export REPO="github:ahbk/my-nixos/add-host-helsinki"

main() {
    repo=${2:-$REPO}
    echo "$1"
    "$1" "$@"
}

# shellcheck disable=SC2120
build() {
    #gh="github:ahbk/my-nixos/add-host-helsinki"

    host=lenovo
    nix build "$repo#nixosConfigurations.$host.config.system.build.toplevel" \
        --print-out-paths --no-link
}

copy() {
    nix copy --to "ssh://nixbuilder@$host.km" "$(build)"
}

switch() {
    local build
    build=$(build)
    sudo nix-env -p /nix/var/nix/profiles/system --set "$build"
    sudo "$build/bin/switch-to-configuration" switch
}

main "$@"
