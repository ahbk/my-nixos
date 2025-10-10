#!/usr/bin/env bash
# bin/build.sh

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"
# shellcheck source=../libexec/sops-yaml.sh
. "$km_root/libexec/sops-yaml.sh"

build() {
    local target=$1
    # shellcheck disable=SC2153
    if [[ -d $BUILD_HOST ]]; then
        REPO=$BUILD_HOST "$km_root/remote/nixservice.sh" build "$target"
    else
        local build_host
        build_host=$(find-route "$BUILD_HOST")
        "$km_root/bin/as.sh" nix-build ssh -A "nix-build@$build_host" "build $target refresh"
    fi
}

build "$@"
