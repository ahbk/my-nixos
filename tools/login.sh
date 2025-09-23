#!/usr/bin/env bash

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r here

login() {
    "$here/as.sh" "${1%%@*}" "ssh" "$1"
}

login "$@"
