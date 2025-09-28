#!/usr/bin/env bash

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=../libexec/run-with.bash
. "$km_root/libexec/run-with.bash"

login() {
    "$km_root/bin/as.sh" "${1%%@*}" "ssh" "$1" "journalctl -ef"
}

login "$@"
