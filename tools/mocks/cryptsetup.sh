#!/usr/bin/env bash
store=$BATS_TEST_TMPDIR/hostroot/luks-key
key="$(<"${3#--key-file=}")"

if ! cmp -s <(printf %s "$key") "$store"; then
  echo "No key available with this passphrase."
  exit 1
fi

case $1 in
open)
  exit 0
  ;;
luksAddKey)
  cat "${4#--new-keyfile=}" >>"$store"
  ;;
luksRemoveKey)
  grep -Fxv "$key" "$store" >"$store.tmp" && mv "$store.tmp" "$store"
  ;;
*)
  exit 1
  ;;
esac
