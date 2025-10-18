#!/usr/bin/env bats
# tests/id-entities.bats

set -eu

setup() {
  load helpers.sh
  test_cmd=id-entities.sh

  echo "=== BEGIN SETUP ===" >&2
  setup-testenv
  export SOPS_AGE_KEY_FILE="$TESTROOT/keys/root-1"

  # init root 1 (bootstrap)
  SECRET_SEED=<(echo "$test_identity_root_1") "$test_cmd" -r 1 init age-key

  echo "=== END SETUP ===" >&2
}

@test "setup works" {
  artifact=$(age-keygen -y <"keys/root-1")
  root_identity=$(
    CONTEXT="root:1:age-key" org-toml.sh "public-artifacts"
  )

  echo "$artifact" | diff - "$root_identity"
}

@test "no args" {
  run "$test_cmd"
  expect 1 "--help"
}

@test "init host works" {
  mock-host "testhost"
  local tmpkey testhost_backend="enc/host-testhost.yaml"

  tmpkey=$(mktemp "$TESTROOT/XXXXXX")

  run "$test_cmd" -h testhost init
  expect 0 "main"

  SOPS_AGE_KEY_FILE="keys/root-1" run sops decrypt --extract "['identity']" $testhost_backend
  expect 0 "host-testhost"

  # test: host secrets can be decrypted with host key
  SOPS_AGE_KEY_FILE="keys/root-1" sops decrypt --extract "['age-key']" $testhost_backend >"$tmpkey"

  SOPS_AGE_KEY_FILE="$tmpkey" run sops decrypt --extract "['identity']" $testhost_backend
  expect 0 "host-testhost"

  # test: host secrets cant be decrypted with some random key
  age-keygen >"$tmpkey"
  SOPS_AGE_KEY_FILE=$tmpkey run sops decrypt --extract "['identity']" $testhost_backend
  expect 128 "but none were."
}

@test "not authorized" {
  run "$test_cmd" -h testhost init
  expect 0 "main"

  age-keygen >keys/root-1

  # test: can't do stuff with random age key
  run "$test_cmd" -h testhost new age-key
  expect 128 "but none were"
}

@test "next slot" {
  mock-host "testhost"

  run "$test_cmd" -h testhost init age-key
  expect 0 "main"

  run bash -c "$test_cmd -h testhost next-slot luks-key 2>/dev/null"
  expect 0 "0"

  run "$test_cmd" -h testhost new luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost next-slot luks-key
  expect 0 "main"

  run bash -c "$test_cmd -h testhost next-slot luks-key 2>/dev/null"
  expect 0 "1"

  run "$test_cmd" -h testhost new luks-key 1
  expect 0 "main"

  run "$test_cmd" -h testhost unset luks-key
  expect 0 "main"

  run bash -c "$test_cmd -h testhost next-slot luks-key 2>/dev/null"
  expect 0 "0"
}

@test "new root" {
  run "$test_cmd" -r 2 init age-key
  expect 0 "main"

  run "$test_cmd" -r 1 verify age-key
  expect 0 "main"

  run "$test_cmd" -r 2 verify age-key
  expect 0 "main"

  run "$test_cmd" -r 3 verify age-key
  expect 1 "did you spell '3' correctly?"
}

@test "rotate root" {
  LOG_LEVEL=off run org-toml.sh recipients "user-testuser"
  expect 0 "age163e67e8t5wrt4ndy9e92z9gxh6nan06793vmasn8tr2vxxm56qlsvm23at"

  run "$test_cmd" -u testuser init age-key
  expect 0 "main"

  run "$test_cmd" -u testuser verify age-key
  expect 0 "main"

  run "$test_cmd" -r 1 new age-key
  expect 1 "entities are not allowed to rotate their own identity"

  SOPS_AGE_KEY_FILE=$TESTROOT/keys/root-2
  run "$test_cmd" -u testuser verify age-key
  expect 1 "no identity found in '$TESTROOT/keys/root-2'"

  SOPS_AGE_KEY_FILE=$TESTROOT/keys/root-1
  run "$test_cmd" -r 2 init age-key
  expect 0 "main"

  run $test_cmd -u testuser rebuild
  expect 0 "main"

  SOPS_AGE_KEY_FILE=$TESTROOT/keys/root-2
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
  mock-host "testhost"
  $test_cmd -s locksmith init
  $test_cmd -s locksmith new ssh-key

  SECRET_SEED=<(echo "$test_age_key_1") run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost verify age-key
  expect 0 "main"

  run "$test_cmd" -h testhost check age-key
  expect 0 "main"

  run "$test_cmd" -h testhost new-secret age-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify age-key
  expect 1 " > age"

  run "$test_cmd" -h testhost check age-key
  expect 1 "locksmith -> died."

  run "$test_cmd" -h testhost align age-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify age-key
  expect 0 "main"

  run "$test_cmd" -h testhost check age-key
  expect 1 "locksmith -> died."
}

@test "host push age-key" {
  mock-host "testhost"
  $test_cmd -s locksmith init
  $test_cmd -s locksmith new ssh-key

  SECRET_SEED=<(echo "$test_age_key_1") run "$test_cmd" -h testhost init
  expect 0 "main"

  SECRET_SEED=<(echo "$test_age_key_2") run "$test_cmd" -h testhost push age-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify age-key
  expect 0 "main"

  run "$test_cmd" -h testhost check age-key
  expect 0 "main"

  run "$test_cmd" -h testhost new-secret age-key
  expect 0 "main"

  run "$test_cmd" -h testhost push age-key
  expect 1 " > age1hxkj8za4tstrxzlrhn7xpthlrxwnyzquz8er7l48v8zgparape7qyu0aa7"
}

@test "host check luks-key" {
  mock-host "testhost"
  $test_cmd -s locksmith init
  $test_cmd -s locksmith new ssh-key

  SECRET_SEED=<(echo "$test_age_key_1") run "$test_cmd" -h testhost init
  expect 0 "main"

  SECRET_SEED=<(echo "$test_luks_key_1") run "$test_cmd" -h testhost new luks-key
  expect 1 "has trailing newline"

  SECRET_SEED=<(echo -n "$test_luks_key_1") run "$test_cmd" -h testhost new luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost check luks-key
  expect 0 "main"

  SECRET_SEED=<(echo -n "$test_luks_key_2") run "$test_cmd" -h testhost new luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost check luks-key
  expect 1 "locksmith -> No key available with this passphrase."
}

@test "host push luks-key" {
  mock-host "testhost"
  $test_cmd -s locksmith init
  $test_cmd -s locksmith new ssh-key

  SECRET_SEED=<(echo "$test_age_key_1") run "$test_cmd" -h testhost init
  expect 0 "main"

  SECRET_SEED=<(echo -n "$test_luks_key_2") run "$test_cmd" -h testhost new luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost check luks-key
  expect 1 "No key available with this passphrase."

  SECRET_SEED=<(echo -n "$test_luks_key_1") run "$test_cmd" -h testhost new luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost check luks-key
  expect 0 "main"

  SECRET_SEED=<(echo -n "$test_luks_key_2") run "$test_cmd" -h testhost push luks-key
  expect 0 "main"

  run "$test_cmd" -h testhost check luks-key 0
  expect 0 "main"

  run "$test_cmd" -h testhost check luks-key 1
  expect 0 "main"

  SECRET_SEED=<(echo -n "$test_luks_key_2") run "$test_cmd" -h testhost push luks-key 2
  expect 1 "component ['luks-key--2'] not found"

  SECRET_SEED=<(echo -n "$test_luks_key_1") run "$test_cmd" -h testhost push luks-key 0
  expect 0 "main"

  run "$test_cmd" -h testhost check luks-key 2
  expect 1 "locksmith -> empty payload"

  run "$test_cmd" -h testhost check luks-key 1
  expect 0 "main"

  run "$test_cmd" -h testhost check luks-key
  expect 1 "No key available with this passphrase."
}

@test "host pull ssh-key" {
  mock-host "testhost"

  run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost new ssh-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify ssh-key
  expect 0 "main"

  run "$test_cmd" -h testhost check ssh-key
  expect 1 " > ssh-ed25519 AAA"

  run "$test_cmd" -h testhost pull ssh-key
  expect 0 "main"

  run "$test_cmd" -h testhost check ssh-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify ssh-key
  expect 1 " > ssh-ed25519 AAAA"
}

@test "host new ssh-key (no artifact)" {
  mock-host "testhost"

  run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost new-secret ssh-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify ssh-key
  expect 1 "artifacts/host-testhost-ssh-key.pub"
}

@test "host new wg-key" {
  mock-host "testhost"

  run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost new wg0-key
  expect 0 "main"

  run "$test_cmd" -h testhost new wg1-key
  expect 0 "main"

  run "$test_cmd" -h testhost new wg2-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify wg0-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify wg1-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify wg2-key
  expect 0 "main"

  run test -f "$TESTROOT/artifacts/host-testhost-wg0-key.pub"
  expect 0

  run test -f "$TESTROOT/artifacts/host-testhost-wg1-key.pub"
  expect 0

  run test -f "$TESTROOT/artifacts/host-testhost-wg2-key.pub"
  expect 0
}

@test "host new wg-key (mismatch)" {
  mock-host "testhost"

  run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost new wg0-key
  expect 0 "main"

  run "$test_cmd" -h testhost new-secret wg0-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify wg0-key
  expect 1 " > "
}

@test "host new nix-cache-key" {
  mock-host "testhost"

  run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost new nix-cache-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify nix-cache-key
  expect 0 "main"

  run test -s "$TESTROOT/artifacts/host-testhost-nix-cache-key.pub"
  expect 0
}

@test "host new nix-cache-key (missing/mismatch)" {
  mock-host "testhost"

  run "$test_cmd" -h testhost init
  expect 0 "main"

  run "$test_cmd" -h testhost new-secret nix-cache-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify nix-cache-key
  expect 1 "artifacts/host-testhost-nix-cache-key.pub"

  run "$test_cmd" -h testhost align nix-cache-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify nix-cache-key
  expect 0 "main"

  run "$test_cmd" -h testhost new-secret nix-cache-key
  expect 0 "main"

  run "$test_cmd" -h testhost verify nix-cache-key
  expect 1 "\ No newline"
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

  run test -f "$TESTROOT/artifacts/user-testuser-ssh-key.pub"
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

@test "user new ssh-key (no artifacts)" {
  run "$test_cmd" -u testuser init
  expect 0 "main"

  run "$test_cmd" -u testuser new-secret ssh-key
  expect 0 "main"

  run "$test_cmd" -u testuser verify ssh-key
  expect 1 "artifacts/user-testuser-ssh-key.pub"
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
  expect 0 "main"

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
  run "$test_cmd" -s domain-local init
  expect 0 "main"

  run "$test_cmd" -s domain-local new tls-cert
  expect 0 "main"

  run "$test_cmd" -s domain-local verify tls-cert
  expect 0 "main"

  run test -f "$TESTROOT/artifacts/service-domain-local-tls-cert.pem"
  expect 0
}

@test "domain new tls-cert (mismatch)" {
  run "$test_cmd" -s domain-local init
  expect 0 "main"

  run "$test_cmd" -s domain-local new tls-cert
  expect 0 "main"

  run "$test_cmd" -s domain-local new-secret tls-cert
  expect 0 "main"

  run "$test_cmd" -s domain-local verify tls-cert
  expect 1 "> MCow"
}

@test "entities with hyphens in their name" {
  run "$test_cmd" -s sysctl-user-portal init
  expect 0 "main"

  run "$test_cmd" sysctl-user-portal new ssh-key
  expect 0 "main"

  run test -f "$TESTROOT/artifacts/service-sysctl-user-portal-ssh-key.pub"
  expect 0

  run "$test_cmd" sysctl-user-portal new secret-key
  expect 0 "main"

  run "$test_cmd" sysctl-user-portal verify secret-key
  expect 0 "main"

  run "$test_cmd" sysctl-user-portal rebuild
  expect 0 "main"

  run "$test_cmd" sysctl-user-portal verify secret-key
  expect 0 "main"
}

@test "misc madness" {
  run "$test_cmd" -s domain-local init
  expect 0 "main"

  run "$test_cmd" -s domain-local init
  expect 1 "already exists"

  run "$test_cmd" -s domain-loca new
  expect 1 "did you spell 'domain-loca' correctly?"

  run "$test_cmd" -r 1 new ssh-key
  expect 1 "not allowed"

  run "$test_cmd" -u testuser init
  expect 0 "main"

  run "$test_cmd" -u testuser cat-secret passwd
  expect 1 "component ['passwd'] not found"

  run "$test_cmd" -h testhost init
  expect 0 "main"
}

test_identity_root_1=AGE-SECRET-KEY-1DJDMVRRC7UNF8HSKVSGQCWFNMJ5HTRT6HT2MDML9JZ54GCW8TYNSSWWL8D

test_age_key_1=AGE-SECRET-KEY-1L0EJY3FLSYHDE46Y80F0KLUKUWP6V3J340UR7G2GWNFGXJQ0P6ZQ6X37TN
test_age_key_2=AGE-SECRET-KEY-1V782VQAQT6QJPARYTCD8CLES04Q83V068FRFDWG02HGLE96U93FSVACDKF

test_luks_key_1="luks1-Atzc2gtZWQyNTUxO"
test_luks_key_2="luks2-roGxnLozh/+wBGot"
