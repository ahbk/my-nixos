#!/usr/bin/env bash
# apply.sh

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"

declare -x target build_host="stationary"

apply() {
    target=$1
    with build
    log important "$build"
    "$km_root/bin/as.sh" nixbuilder ssh "nixbuilder@$target.km" "copy $build_host $build"
    "$km_root/bin/as.sh" nixswitcher ssh "nixswitcher@$target.km" "$build"
}

declare -g build
build() {
    "$km_root/bin/build.sh" "$@"
}

apply "$@"
