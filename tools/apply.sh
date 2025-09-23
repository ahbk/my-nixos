#!/usr/bin/env bash

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r here

. "$here/run-with.bash"

declare -x target

apply() {
    target=$1
    with build
    log important "$build"
    "$here/as.sh" nixbuilder ssh "nixbuilder@$target.km" "copy stationary $build"
    "$here/as.sh" nixswitcher ssh "nixswitcher@$target.km" "$build"
}

declare -g build
build() {
    "$here/as.sh" nixbuilder ssh nixbuilder@stationary.km "build $target"
}

apply "$@"
