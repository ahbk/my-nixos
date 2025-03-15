#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  printf "Usage: $0 <passwd|wg|mail> <user>\n"
  exit 1
fi

if [[ "$1" = "passwd" ]]; then
  plain_password=$(agenix -d "linux-passwd-plain-$2.age")
  hashed_password=$(echo "$plain_password" | mkpasswd -sm bcrypt)
  echo "$hashed_password" | agenix -e "linux-passwd-hashed-$2.age"
  printf "'linux-passwd-hashed-$2.age' generated."
  exit 1
fi

if [[ "$1" = "mail" ]]; then
  plain_password=$(agenix -d "mail-plain-$2.age")
  hashed_password=$(echo "$plain_password" | mkpasswd -sm bcrypt)
  echo "$hashed_password" | agenix -e "mail-hashed-$2.age"
  printf "'mail-hashed-$2.age' generated."
  exit 1
fi

if [[ "$1" = "wg" ]]; then
  private_key=$(wg genkey)
  echo $private_key | agenix -e "wg-key-$2.age"
  public_key=$(echo "$private_key" | wg pubkey)
  echo "$public_key" > ../keys/wg-$2.pub
  printf "'./wg-key-$2.age' generated.\n"
  printf "'../keys/wg-$2.age' generated."
  exit 1
fi
