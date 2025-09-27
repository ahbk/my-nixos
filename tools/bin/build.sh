#!/usr/bin/env bash
# build.sh

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"

declare -x build_host="stationary"

build() {
    local target=$1
    "$km_root/bin/as.sh" nixbuilder ssh nixbuilder@$build_host.km "build $target"
}

build "$@"
