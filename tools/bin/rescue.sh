#!/usr/bin/env bash

set -euo pipefail

km_root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

rescue() {
    "$km_root/bin/as.sh" "rescue" "ssh" "root@$1.km"
}

rescue "$@"
