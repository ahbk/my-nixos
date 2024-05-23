#!/usr/bin/env bash

set -xeuo pipefail

hash() {
  plain_password=$(agenix -d "linux-passwd-plain-$1.age")
  hashed_password=$(echo "$plain_password" | mkpasswd -sm bcrypt)
  echo "$hashed_password" | agenix -e "linux-passwd-hashed-$1.age"
}

wg_pubkey() {
  private_key=$(agenix -d "wg-key-$1.age")
  public_key=$(echo "$private_key" | wg pubkey)
  echo "$public_key" > ../keys/wg-key-$1.pub
}

[[ "$1" = "hash" ]] && hash $2
[[ "$1" = "wg" ]] && wg_pubkey $2
