#!/usr/bin/env bash
# apply.sh

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r here

. "$here/run-with.bash"

declare -x target build_host="stationary"

apply() {
    target=$1
    with build
    log important "$build"
    "$here/as.sh" nixbuilder ssh "nixbuilder@$target.km" "copy $build_host $build"
    "$here/as.sh" nixswitcher ssh "nixswitcher@$target.km" "$build"
}

declare -g build
build() {
    "$here/build.sh" "$@"
}

apply "$@"
