#!/usr/bin/env bats
set -e

root_1=AGE-SECRET-KEY-1DJDMVRRC7UNF8HSKVSGQCWFNMJ5HTRT6HT2MDML9JZ54GCW8TYNSSWWL8D
age1=AGE-SECRET-KEY-1L0EJY3FLSYHDE46Y80F0KLUKUWP6V3J340UR7G2GWNFGXJQ0P6ZQ6X37TN
age2=AGE-SECRET-KEY-1V782VQAQT6QJPARYTCD8CLES04Q83V068FRFDWG02HGLE96U93FSVACDKF

ssh1="-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACDEE3csx1IE4hhJQOzYQh7xZ8iZY6wj1C1xYp2DjxjmOAAAAKDYIpSm2CKU
pgAAAAtzc2gtZWQyNTUxOQAAACDEE3csx1IE4hhJQOzYQh7xZ8iZY6wj1C1xYp2DjxjmOA
AAAEA4YkpxaWCNi2sH27/j3HB+cMO81OHPrAzAeD15B1N9BcQTdyzHUgTiGElA7NhCHvFn
yJljrCPULXFinYOPGOY4AAAAF3Rlc3R1c2VyQHRlc3Rob3N0LmxvY2FsAQIDBAUG
-----END OPENSSH PRIVATE KEY-----"

ssh2="-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACA14z675Z3GWyxUL52M7HXZ8J7Yv9dsVEMU42433oHBRwAAAJDaNIZJ2jSG
SQAAAAtzc2gtZWQyNTUxOQAAACA14z675Z3GWyxUL52M7HXZ8J7Yv9dsVEMU42433oHBRw
AAAEAXNvZ6ERXP6Ap2WicroGxnLozh/+wBGot6zcKm4dIPcDXjPrvlncZbLFQvnYzsddnw
nti/12xUQxTjbjfegcFHAAAAC2FsZXhAbGVub3ZvAQI=
-----END OPENSSH PRIVATE KEY-----"

luks1="luks1-Atzc2gtZWQyNTUxO"
luks2="luks2-roGxnLozh/+wBGot"

setup() {
  testroot=$BATS_TEST_TMPDIR/testroot
  script_name=./tools/id-entities.sh
  export LOG_LEVEL=debug
  export SOPS_AGE_KEY_FILE="keys/root-1"

  echo "=== BEGIN SETUP ===" >&2

  # environment
  mkdir -p "$testroot/enc"
  mkdir -p "$testroot/keys"
  mkdir -p "$testroot/public"
  cp -a "./tools" "$testroot"
  cd "$testroot"

  export PATH="$testroot/tools/dry-bin:$PATH"
  setup-testhost

  # init root 1 (bootstrap)
  SECRET_FILE=<(echo "$root_1") "$script_name" -r 1 init age-key

  $script_name -u keyservice init
  $script_name -u keyservice new ssh-key

  echo "=== END SETUP ===" >&2
}

setup-testhost() {
  hostroot=$BATS_TEST_TMPDIR/hostroot
  mkdir -p "$hostroot/keys"

  echo "$age1" >"$hostroot/age-key"
  echo "$ssh1" >"$hostroot/ssh-key"
  chmod 600 "$hostroot/ssh-key"
  echo -n "$luks1" >"$hostroot/luks-key"
}

teardown() {
  rm -r "$testroot"
}

strip-color() {
  sed 's/\x1B\[[0-9;]*[JKmsu]//g'
}

check-output() {
  local expected_status=$1
  local expected_lastline=$2

  echo ""
  echo "in '$BATS_TEST_NAME'"
  echo "run '$BATS_RUN_COMMAND':" >&2
  echo "$output" >&2

  lastline=$(echo "$output" | tail -n 1 | strip-color)

  [[ $lastline == *"$expected_lastline"* && "$status" == "$expected_status" ]] && return 0

  echo ""
  echo "'$BATS_RUN_COMMAND' failed:" >&2
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
  run "$script_name"
  check-output 1 "--help"
}

@test "init host works" {
  local tmpkey testhost_backend="enc/host-testhost.yaml"

  tmpkey=$(mktemp "$testroot/XXXXXX")

  run "$script_name" -h testhost init
  check-output 0 "completed"

  SOPS_AGE_KEY_FILE="keys/root-1" run sops decrypt --extract "['init']" $testhost_backend
  check-output 0 "true"

  # test: host secrets can be decrypted with host key
  SOPS_AGE_KEY_FILE="keys/root-1" sops decrypt --extract "['age-key']" $testhost_backend >"$tmpkey"
  SOPS_AGE_KEY_FILE=$tmpkey run sops decrypt --extract "['init']" $testhost_backend
  check-output 0 "true"

  # test: host secrets cant be decrypted with some random key
  age-keygen >"$tmpkey"
  SOPS_AGE_KEY_FILE=$tmpkey run sops decrypt --extract "['init']" $testhost_backend
  check-output 128 "but none were."
}

@test "not authorized" {
  run "$script_name" -h testhost init
  check-output 0 "completed"

  age-keygen >keys/root-1

  # test: can't do stuff with random age key
  run "$script_name" -h testhost new age-key
  check-output 1 "no identity found"
}

@test "new root" {
  run "$script_name" -r 2 new age-key
  check-output 0 "completed"

  run "$script_name" -r 1 verify age-key
  check-output 0 "completed"

  run "$script_name" -r 2 verify age-key
  check-output 0 "completed"

  run "$script_name" -r 3 verify age-key
  check-output 1 "root-3 not found"
}

@test "rotate root" {
  run "$script_name" -u testuser init age-key
  check-output 0 "completed"

  run "$script_name" -u testuser verify age-key
  check-output 0 "completed"

  run "$script_name" -r 1 new age-key
  check-output 1 "can't rotate current"

  SOPS_AGE_KEY_FILE=keys/root-2
  run "$script_name" -u testuser verify age-key
  check-output 1 "no identity found in 'keys/root-2'"

  SOPS_AGE_KEY_FILE=keys/root-1
  run "$script_name" -r 2 new age-key
  check-output 0 "completed"

  run $script_name -u testuser updatekeys
  check-output 0 "completed"

  SOPS_AGE_KEY_FILE=keys/root-2
  run "$script_name" -u testuser verify age-key
  check-output 0 "completed"

  run "$script_name" -r 1 new age-key
  check-output 0 "completed"

  run $script_name -u testuser updatekeys
  check-output 0 "completed"

  run "$script_name" -u testuser verify age-key
  check-output 0 "completed"
}

@test "host new age-key" {
  SECRET_FILE=<(echo $age1) run "$script_name" -h testhost init
  check-output 0 "completed"

  run "$script_name" -h testhost verify age-key
  check-output 0 "completed"

  run "$script_name" -h testhost new-secret age-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify age-key
  check-output 1 " > age"

  run "$script_name" -h testhost align age-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify age-key
  check-output 1 "keyservice: died."
}

@test "host sideload age-key" {
  SECRET_FILE=<(echo $age1) run "$script_name" -h testhost init
  check-output 0 "completed"

  SECRET_FILE=<(echo $age2) run "$script_name" -h testhost sideload age-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify age-key
  check-output 0 "completed"

  run "$script_name" -h testhost new-secret age-key
  check-output 0 "completed"

  run "$script_name" -h testhost sideload age-key
  check-output 1 " > age1hxkj8za4tstrxzlrhn7xpthlrxwnyzquz8er7l48v8zgparape7qyu0aa7"
}

@test "host check luks-key" {
  SECRET_FILE=<(echo $age1) run "$script_name" -h testhost init
  check-output 0 "completed"

  SECRET_FILE=<(echo "$luks1") run "$script_name" -h testhost new luks-key
  check-output 1 "has trailing newline"

  SECRET_FILE=<(echo -n "$luks1") run "$script_name" -h testhost new luks-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify luks-key
  check-output 0 "completed"

  SECRET_FILE=<(echo -n "$luks2") run "$script_name" -h testhost new luks-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify luks-key
  check-output 1 "keyservice: No key available with this passphrase."
}

@test "host sideload luks-key" {
  SECRET_FILE=<(echo $age1) run "$script_name" -h testhost init
  check-output 0 "completed"

  SECRET_FILE=<(echo -n "$luks1") run "$script_name" -h testhost new luks-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify luks-key
  check-output 0 "completed"

  SECRET_FILE=<(echo -n $luks2) run "$script_name" -h testhost sideload luks-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify luks-key
  check-output 0 "completed"
}

@test "host align ssh-key" {
  run "$script_name" -h testhost init
  check-output 0 "completed"

  run "$script_name" -h testhost new ssh-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify ssh-key
  check-output 1 " > ssh-ed25519 AAAA"

  run "$script_name" -h testhost align ssh-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify ssh-key
  check-output 0 "completed"
}

@test "host new ssh-key (no public)" {
  run "$script_name" -h testhost init
  check-output 0 "completed"

  run "$script_name" -h testhost new-secret ssh-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify ssh-key
  check-output 2 " No such file or directory"
}

@test "host new wg-key" {
  run "$script_name" -h testhost init
  check-output 0 "completed"

  run "$script_name" -h testhost new wg-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify wg-key
  check-output 0 "completed"

  [[ -f $testroot/public/host-testhost-wg-key.pub ]]
}

@test "host new wg-key (mismatch)" {
  run "$script_name" -h testhost init
  check-output 0 "completed"

  run "$script_name" -h testhost new wg-key
  check-output 0 "completed"

  run "$script_name" -h testhost new-secret wg-key
  check-output 0 "completed"

  run "$script_name" -h testhost verify wg-key
  check-output 1 ">"
}

@test "user new age-key" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new age-key
  check-output 0 "completed"

  run "$script_name" -u testuser verify age-key
  check-output 0 "completed"
}

@test "user new age-key (mismatch)" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new age-key
  check-output 0 "completed"

  run "$script_name" -u testuser new-secret age-key
  check-output 0 "completed"

  run "$script_name" -u testuser verify age-key
  check-output 1 ">"
}

@test "user new ssh-key" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new ssh-key
  check-output 0 "completed"

  run "$script_name" -u testuser verify ssh-key
  check-output 0 "completed"

  [[ -f $testroot/public/user-testuser-ssh-key.pub ]]
}

@test "user new ssh-key (mismatch)" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new ssh-key
  check-output 0 "completed"

  run "$script_name" -u testuser new-secret ssh-key
  check-output 0 "completed"

  run "$script_name" -u testuser verify ssh-key
  check-output 1 " > ssh-ed25519 AAAA"
}

@test "user new ssh-key (no public)" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new-secret ssh-key
  check-output 0 "completed"

  run "$script_name" -u testuser verify ssh-key
  check-output 2 " No such file or directory"
}

@test "user new passwd" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new passwd
  check-output 0 "completed"

  run "$script_name" -u testuser verify passwd
  check-output 0 "completed"
}

@test "user new passwd (mismatch)" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new passwd

  run "$script_name" -u testuser new-secret passwd
  check-output 0 "completed"

  run "$script_name" -u testuser verify passwd
  check-output 1 ">"

  run "$script_name" -u testuser align passwd
  check-output 0 "completed"

  run "$script_name" -u testuser verify passwd
  check-output 0 "completed"
}

@test "domain new tls-cert" {
  run "$script_name" -d testdomain init
  check-output 0 "completed"

  run "$script_name" -d testdomain new tls-cert
  check-output 0 "completed"

  run "$script_name" -d testdomain verify tls-cert
  check-output 0 "completed"

  [[ -f $testroot/public/domain-testdomain-tls-cert.pem ]]
}

@test "domain new tls-cert (mismatch)" {
  run "$script_name" -d testdomain init
  check-output 0 "completed"

  run "$script_name" -d testdomain new tls-cert
  check-output 0 "completed"

  run "$script_name" -d testdomain new-secret tls-cert
  check-output 0 "completed"

  run "$script_name" -d testdomain verify tls-cert
  check-output 1 "> MCow"
}
