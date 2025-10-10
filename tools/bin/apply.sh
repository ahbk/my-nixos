#!/usr/bin/env bash
# tools/bin/apply.sh

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"
# shellcheck source=../libexec/sops-yaml.sh
. "$km_root/libexec/sops-yaml.sh"

declare -x \
    target=${1:?target required} \
    BUILD_HOST=${BUILD_HOST:-$(read-setting "build-host")}

apply() {
    target_address=$(find-route "$target")

    log info "use $BUILD_HOST to build $target (at $target_address)"

    with build
    log important "$build"

    if [[ -d "$BUILD_HOST" ]]; then
        "$km_root/bin/as.sh" nix-push nix copy --to "ssh://nix-push@$target_address" "$build"
    else
        local build_host
        build_host="http://$(find-route "$BUILD_HOST" 5000):5000"
        "$km_root/bin/as.sh" nix-build ssh "nix-build@$target_address" "pull $build $build_host"
    fi

    "$km_root/bin/as.sh" nix-switch ssh "nix-switch@$target_address" "$build"
}

declare -g build
build() {
    "$km_root/bin/build.sh" "$target"
}

apply
