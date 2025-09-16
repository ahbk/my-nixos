#!/usr/bin/env bats
set -eu

setup() {
  here="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  testroot=$BATS_TEST_TMPDIR/testroot
  test_cmd=$here/id-entities.sh
  export LOG_LEVEL=debug
  export SOPS_AGE_KEY_FILE="keys/root-1"

  echo "=== BEGIN SETUP ===" >&2

  mkdir -p "$testroot"
  cp -a "$here" "$testroot"
  cd "$testroot"
  mkdir "enc" "keys" "public"

  export PATH="$testroot/tools/dry-bin:$PATH"

  # init root 1 (bootstrap)
  SEED_SECRET=<(echo "$test_identity_root_1") "$test_cmd" -r 1 init age-key

  $test_cmd -s keyservice init
  $test_cmd -s keyservice new ssh-key

  echo "=== END SETUP ===" >&2
}

setup-testhost() {
  local hostroot=$BATS_TEST_TMPDIR/testhost
  mkdir -p "$hostroot/keys"

  echo "$test_age_key_1" >"$hostroot/age-key"
  echo "$test_ssh_key_1" >"$hostroot/ssh-key"
  chmod 600 "$hostroot/ssh-key"
  echo "$test_luks_key_1" >"$hostroot/luks-key"
}

strip-color() {
  sed 's/\x1B\[[0-9;]*[JKmsu]//g'
}

expect() {
  local lastline
  local expected_status=$1
  local expected_lastline=${2:-}

  echo "" >&2
  echo "in '$BATS_TEST_NAME'" >&2
  echo "run '$BATS_RUN_COMMAND':" >&2
  echo "$output" >&2

  lastline=$(echo "$output" | tail -n 1 | strip-color)

  [[ $lastline == *"$expected_lastline"* && "$status" == "$expected_status" ]] && return 0

  echo "" >&2
  echo "in '$BATS_TEST_NAME'" >&2
  echo "run '$BATS_RUN_COMMAND' failed:" >&2
  echo "expected: $expected_lastline ($expected_status)" >&2
  echo "got:      $lastline ($status)" >&2
  return 1
}

@test "setup works" {
  public_key=$(age-keygen -y <"keys/root-1")
  root_identity=$(yq ".identities.root-1" .sops.yaml)

  [[ $public_key == "$root_identity" ]]
}

@test "no args" {
  run "$test_cmd"
  expect 1 "--help"
}

@test "init host works" {
  setup-testhost
  local tmpkey testhost_backend="enc/host-testhost.yaml"

  tmpkey=$(mktemp "$testroot/XXXXXX")

  run "$test_cmd" -h testhost init
  expect 0 "main"

  SOPS_AGE_KEY_FILE="keys/root-1" run sops decrypt --extract "['init']" $testhost_backend
  expect 0 "true"

  # test: host secrets can be decrypted with host key
  SOPS_AGE_KEY_FILE="keys/root-1" sops decrypt --extract "['age-key']" $testhost_backend >"$tmpkey"
  SOPS_AGE_KEY_FILE=$tmpkey run sops decrypt --extract "['init']" $testhost_backend
  expect 0 "true"

  # test: host secrets cant be decrypted with some random key
  age-keygen >"$tmpkey"
  SOPS_AGE_KEY_FILE=$tmpkey run sops decrypt --extract "['init']" $testhost_backend
  expect 128 "but none were."
}

@test "not authorized" {
  run "$test_cmd" -h testhost init
  expect 0 "main"

  age-keygen >keys/root-1

  # test: can't do stuff with random age key
  run "$test_cmd" -h testhost new age-key
  expect 1 "no identity found"
}

@test "next slot" {
  setup-testhost
  run "$test_cmd" -h testhost init age-key
  expect 0 "main"

  run bash -c "$test_cmd -h testhost next-slot luks-key 2>/dev/null"
  expect 0 "0"

  run "$test_cmd" -h testhost new luks-key
  expect 0 "main"

  run bash -c "$test_cmd -h testhost next-slot luks-key 2>/dev/null"
  expect 0 "1"

  run "$test_cmd" -h testhost new luks-key 1
  expect 0 "main"

  run "$test_cmd" -h testhost unset-secret luks-key
  expect 0 "main"

  run bash -c "$test_cmd -h testhost next-slot luks-key 2>/dev/null"
  expect 0 "0"
}

@test "exists" {
  run "$test_cmd" -r 1 exists age-key
  expect 0 "main"

  run "$test_cmd" -u testuser init age-key
  expect 0 "main"

  run "$test_cmd" -u testuser exists ssh-key
  expect 1 "not found"

  run "$test_cmd" -u testuser cat-secret ssh-key
  expect 1 "failed to get secret"

  run "$test_cmd" -u testuser new ssh-key
  expect 0 "main"

  run "$test_cmd" -u testuser exists ssh-key
  expect 0 "main"
}

@test "new root" {
  run "$test_cmd" -r 2 new age-key
  expect 0 "main"

  run "$test_cmd" -r 1 verify age-key
  expect 0 "main"

  run "$test_cmd" -r 2 verify age-key
  expect 0 "main"

  run "$test_cmd" -r 3 verify age-key
  expect 1 "age-keygen"
}

@test "rotate root" {
  run "$test_cmd" -u testuser init age-key
  expect 0 "main"

  run "$test_cmd" -u testuser verify age-key
  expect 0 "main"

  run "$test_cmd" -r 1 new age-key
  expect 1 "can't rotate current"

  SOPS_AGE_KEY_FILE=keys/root-2
  run "$test_cmd" -u testuser verify age-key
  expect 1 "no identity found in 'keys/root-2'"

  SOPS_AGE_KEY_FILE=keys/root-1
  run "$test_cmd" -r 2 new age-key
  expect 0 "main"

  run $test_cmd -u testuser rebuild
  expect 0 "main"

  SOPS_AGE_KEY_FILE=keys/root-2
  run "$test_cmd" -u testuser verify age-key
  expect 0 "main"

  run "$test_cmd" -r 1 new age-key
  expect 0 "main"

  run $test_cmd -u testuser rebuild
  expect 0 "main"

  run "$test_cmd" -u testuser verify age-key
  expect 0 "main"
}

@test "host new age-key" {
  setup-testhost
  SEED_SECRET=<(echo "$test_age_key_1") run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost verify age-key
  expect 0 "main"

  run "$test_cmd" -h testhost new-secret age-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify age-key
  expect 1 " > age"

  run "$test_cmd" -h testhost align age-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify age-key
  expect 1 "keyservice: died."
}

@test "host sideload age-key" {
  setup-testhost
  SEED_SECRET=<(echo "$test_age_key_1") run "$test_cmd" -h testhost init
  expect 0 "main"

  SEED_SECRET=<(echo "$test_age_key_2") run "$test_cmd" -h testhost sideload age-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify age-key
  expect 0 "main"

  run "$test_cmd" -h testhost new-secret age-key
  expect 0 "main"

  run "$test_cmd" -h testhost sideload age-key
  expect 1 " > age1hxkj8za4tstrxzlrhn7xpthlrxwnyzquz8er7l48v8zgparape7qyu0aa7"
}

@test "host check luks-key" {
  setup-testhost
  SEED_SECRET=<(echo "$test_age_key_1") run "$test_cmd" -h testhost init
  expect 0 "main"

  SEED_SECRET=<(echo "$test_luks_key_1") run "$test_cmd" -h testhost new luks-key
  expect 1 "has trailing newline"

  SEED_SECRET=<(echo -n "$test_luks_key_1") run "$test_cmd" -h testhost new luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key
  expect 0 "main"

  SEED_SECRET=<(echo -n "$test_luks_key_2") run "$test_cmd" -h testhost new luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key
  expect 1 "keyservice: No key available with this passphrase."
}

@test "host sideload luks-key" {
  setup-testhost
  SEED_SECRET=<(echo "$test_age_key_1") run "$test_cmd" -h testhost init
  expect 0 "main"

  SEED_SECRET=<(echo -n "$test_luks_key_2") run "$test_cmd" -h testhost new luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key
  expect 1 "No key available with this passphrase."

  SEED_SECRET=<(echo -n "$test_luks_key_1") run "$test_cmd" -h testhost new luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key
  expect 0 "main"

  SEED_SECRET=<(echo -n "$test_luks_key_2") run "$test_cmd" -h testhost sideload luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key 0
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key 1
  expect 0 "main"

  SEED_SECRET=<(echo -n "$test_luks_key_2") run "$test_cmd" -h testhost sideload luks-key 2
  expect 1 "No key available"

  SEED_SECRET=<(echo -n "$test_luks_key_2") run "$test_cmd" -h testhost sideload luks-key 1
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key 2
  expect 1 "No key available with this passphrase."

  run "$test_cmd" -h testhost verify luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key 1
  expect 1 "No key available with this passphrase."
}

@test "host align ssh-key" {
  setup-testhost
  run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost new ssh-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify ssh-key
  expect 1 " > ssh-ed25519 AAAA"

  run "$test_cmd" -h testhost align ssh-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify ssh-key
  expect 0 "main"
}

@test "host new ssh-key (no public)" {
  setup-testhost
  run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost new-secret ssh-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify ssh-key
  expect 2 "No such file or directory"
}

@test "host new wg-key" {
  setup-testhost
  run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost new wg-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify wg-key
  expect 0 "main"

  run test -f "$testroot/public/host-testhost-wg-key.pub"
  expect 0
}

@test "host new wg-key (mismatch)" {
  setup-testhost
  run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost new wg-key
  expect 0 "main"

  run "$test_cmd" -h testhost new-secret wg-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify wg-key
  expect 1 " > "
}

@test "user new age-key" {
  run "$test_cmd" -u testuser init
  expect 0 "main"

  run "$test_cmd" -u testuser verify age-key
  expect 0 "main"

  run "$test_cmd" -u testuser new-secret age-key
  expect 0 "main"

  run "$test_cmd" -u testuser verify age-key
  expect 1 " > age"

  run "$test_cmd" -u testuser align age-key
  expect 0 "main"

  run "$test_cmd" -u testuser verify age-key
  expect 0 "main"

}

@test "user new age-key (mismatch)" {
  run "$test_cmd" -u testuser init
  expect 0 "main"

  run "$test_cmd" -u testuser new age-key
  expect 0 "main"

  run "$test_cmd" -u testuser new-secret age-key
  expect 0 "main"

  run "$test_cmd" -u testuser verify age-key
  expect 1 ">"
}

@test "user new ssh-key" {
  run "$test_cmd" -u testuser init
  expect 0 "main"

  run "$test_cmd" -u testuser new ssh-key
  expect 0 "main"

  run "$test_cmd" -u testuser verify ssh-key
  expect 0 "main"

  run test -f "$testroot/public/user-testuser-ssh-key.pub"
  expect 0
}

@test "user new ssh-key (mismatch)" {
  run "$test_cmd" -u testuser init
  expect 0 "main"

  run "$test_cmd" -u testuser new ssh-key
  expect 0 "main"

  run "$test_cmd" -u testuser new-secret ssh-key
  expect 0 "main"

  run "$test_cmd" -u testuser verify ssh-key
  expect 1 " > ssh-ed25519 AAAA"
}

@test "user new ssh-key (no public)" {
  run "$test_cmd" -u testuser init
  expect 0 "main"

  run "$test_cmd" -u testuser new-secret ssh-key
  expect 0 "main"

  run "$test_cmd" -u testuser verify ssh-key
  expect 2 " No such file or directory"
}

@test "user new passwd" {
  run "$test_cmd" -u testuser init
  expect 0 "main"

  run "$test_cmd" -u testuser new passwd
  expect 0 "main"

  run "$test_cmd" -u testuser verify passwd
  expect 0 "main"
}

@test "user new passwd (mismatch)" {
  run "$test_cmd" -u testuser init
  expect 0 "main"

  run "$test_cmd" -u testuser new passwd

  run "$test_cmd" -u testuser new-secret passwd
  expect 0 "main"

  run "$test_cmd" -u testuser verify passwd
  expect 1 ">"

  run "$test_cmd" -u testuser align passwd
  expect 0 "main"

  run "$test_cmd" -u testuser verify passwd
  expect 0 "main"
}

@test "domain new tls-cert" {
  run "$test_cmd" -d testdomain init
  expect 0 "main"

  run "$test_cmd" -d testdomain new tls-cert
  expect 0 "main"

  run "$test_cmd" -d testdomain verify tls-cert
  expect 0 "main"

  run test -f "$testroot/public/domain-testdomain-tls-cert.pem"
  expect 0
}

@test "domain new tls-cert (mismatch)" {
  run "$test_cmd" -d testdomain init
  expect 0 "main"

  run "$test_cmd" -d testdomain new tls-cert
  expect 0 "main"

  run "$test_cmd" -d testdomain new-secret tls-cert
  expect 0 "main"

  run "$test_cmd" -d testdomain verify tls-cert
  expect 1 "> MCow"
}

@test "misc madness" {
  run "$test_cmd" -d testdomain init
  expect 0 "main"

  run "$test_cmd" -d testdomain init
  expect 1 "already exists"

  run "$test_cmd" -d otherdomain new
  expect 1 "correctly?"

  run "$test_cmd" -r 1 new ssh-key
  expect 1 "not allowed"

  run "$test_cmd" -u testuser init
  expect 0 "main"

  run "$test_cmd" -u testuser verify-public age-key
  expect 2 "No such file"

  run "$test_cmd" -u testuser verify-host
  expect 1 "assert: hosts only"
}

test_identity_root_1=AGE-SECRET-KEY-1DJDMVRRC7UNF8HSKVSGQCWFNMJ5HTRT6HT2MDML9JZ54GCW8TYNSSWWL8D
test_age_key_1=AGE-SECRET-KEY-1L0EJY3FLSYHDE46Y80F0KLUKUWP6V3J340UR7G2GWNFGXJQ0P6ZQ6X37TN
test_age_key_2=AGE-SECRET-KEY-1V782VQAQT6QJPARYTCD8CLES04Q83V068FRFDWG02HGLE96U93FSVACDKF

test_ssh_key_1="-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACDEE3csx1IE4hhJQOzYQh7xZ8iZY6wj1C1xYp2DjxjmOAAAAKDYIpSm2CKU
pgAAAAtzc2gtZWQyNTUxOQAAACDEE3csx1IE4hhJQOzYQh7xZ8iZY6wj1C1xYp2DjxjmOA
AAAEA4YkpxaWCNi2sH27/j3HB+cMO81OHPrAzAeD15B1N9BcQTdyzHUgTiGElA7NhCHvFn
yJljrCPULXFinYOPGOY4AAAAF3Rlc3R1c2VyQHRlc3Rob3N0LmxvY2FsAQIDBAUG
-----END OPENSSH PRIVATE KEY-----"

test_luks_key_1="luks1-Atzc2gtZWQyNTUxO"
test_luks_key_2="luks2-roGxnLozh/+wBGot"
