#!/usr/bin/env bash
# bin/build.sh

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"

build() {
    local target=$1
    if [[ -e $BUILD_HOST ]]; then
        REPO=$BUILD_HOST "$km_root/remote/nixservice.sh" build "$target"
    else
        "$km_root/bin/as.sh" nix-build ssh -A "nix-build@$BUILD_HOST.km" "build $target"
    fi
}

build "$@"
