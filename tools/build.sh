#!/usr/bin/env bash
# build.sh

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r here

. "$here/run-with.bash"

declare -x build_host="stationary"

build() {
    local target=$1
    "$here/as.sh" nixbuilder ssh nixbuilder@$build_host.km "build $target"
}

build "$@"
