#!/usr/bin/env bash

set -euo pipefail

mail() {
  plain_password=$(agenix -d "mail-plain-$1.age")
  hashed_password=$(echo "$plain_password" | mkpasswd -sm bcrypt)
  echo "$hashed_password" | agenix -e "mail-hashed-$1.age"
  printf "'mail-hashed-$1.age' generated."
}

linux() {
  plain_password=$(agenix -d "linux-passwd-plain-$1.age")
  hashed_password=$(echo "$plain_password" | mkpasswd -sm bcrypt)
  echo "$hashed_password" | agenix -e "linux-passwd-hashed-$1.age"
  printf "'linux-passwd-hashed-$1.age' generated."
}

wg_pubkey() {
  private_key=$(agenix -d "wg-key-$1.age")
  public_key=$(echo "$private_key" | wg pubkey)
  echo "$public_key" > ../keys/wg-key-$1.pub
  printf "'wg-key-$1.age' generated."
}

if [[ "$#" -eq 0 ]]; then
  printf "Usage: $0 <linux|wg|mail> <user>\n"
  exit 1
fi

[[ "$1" = "hash" ]] && hash $2
[[ "$1" = "mail" ]] && mail $2
[[ "$1" = "wg" ]] && wg_pubkey $2
