#!/usr/bin/env bash
# bin/apply.sh

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"

declare -x target BUILD_HOST=${BUILD_HOST:-stationary}

apply() {
    target=$1
    with build
    log important "$build"

    if [[ -e "$BUILD_HOST" ]]; then
        "$km_root/bin/as.sh" nix-push nix copy --to "ssh://nix-push@$target.km" "$build"
    else
        "$km_root/bin/as.sh" nix-build ssh "nix-build@$target.km" "pull $BUILD_HOST $build"
    fi

    "$km_root/bin/as.sh" nix-switch ssh "nix-switch@$target.km" "$build"
}

declare -g build
build() {
    "$km_root/bin/build.sh" "$target"
}

apply "$@"
