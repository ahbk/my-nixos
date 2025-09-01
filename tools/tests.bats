#!/usr/bin/env bats
set -e
unset SOPS_AGE_KEY_FILE

mock-ssh-keyscan() {
  cat <<EOF
#!/usr/bin/env bash
echo "testhost.local $(ssh-keygen -y -f <(echo "$1"))"
EOF
}

mock-ssh() {
  cat <<EOF
#!/usr/bin/env bash
export LUKS_DEVICE=
export KEY_FILE=$1
./tools/keyservice.sh "\$2"
EOF
}

mock-cryptsetup() {
  cat <<EOF
#!/usr/bin/env bash
EOF
}

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

setup() {
  testroot=$BATS_TEST_TMPDIR/testroot
  script_name=./tools/manage-entities.sh
  export LOG_LEVEL=debug

  echo "=== BEGIN SETUP ===" >&2

  # environment
  mkdir -p "$testroot/keys"
  cp -a "./tools" "$testroot"
  cd "$testroot"

  # mocks
  setup-testhost

  # init root 1 (bootstrap)
  PRIVATE_FILE=<(echo "$root_1") "$script_name" -r 1 init age-key
  export SOPS_AGE_KEY_FILE=keys/root-1

  echo "=== END SETUP ===" >&2
}

setup-testhost() {
  mkdir -p "$testroot/bin"
  export PATH="$testroot/bin:$PATH"

  mock-ssh-keyscan "$ssh1" >"$testroot/bin/ssh-keyscan"

  local hostroot=$BATS_TEST_TMPDIR/hostroot
  mkdir -p "$hostroot/keys"

  echo "$age1" >"$hostroot/keys/host-testhost"
  mock-ssh "$hostroot/keys/host-testhost" >"$testroot/bin/ssh"

  chmod +x "$testroot/bin/"*
}

teardown() {
  rm -r "$testroot"
}

check-output() {
  local expected_status=$1
  local expected_lastline=$2

  echo ""
  echo "run '$BATS_RUN_COMMAND':" >&2
  echo "$output" >&2

  lastline=$(echo "$output" | tail -n 1)

  if [[ $lastline == *"$expected_lastline"* && "$status" == "$expected_status" ]]; then
    return 0
  else
    echo ""
    echo "'$BATS_RUN_COMMAND' failed:" >&2
    echo "expected: $expected_lastline ($expected_status)" >&2
    echo "got:      $lastline ($status)" >&2
    return 1
  fi
}

@test "setup works" {
  key_file=$(yq ".secrets.root" .sops.yaml | entity=1 envsubst)
  [[ "$key_file" == "keys/root-1" ]]

  public_key=$(age-keygen -y <"$key_file")
  [[ $public_key == $(echo "$root_1" | age-keygen -y) ]]

  root_identity=$(yq ".identities.root-1" .sops.yaml)
  [[ $public_key == "$root_identity" ]]
}

@test "no args" {
  run "$script_name"
  check-output 1 "--help"
}

@test "init host works" {
  local tmpkey testhost_backend="hosts/testhost/secrets.yaml"

  tmpkey=$(mktemp "$testroot/XXXXXX")

  run "$script_name" -h testhost init
  check-output 0 "completed"

  run sops decrypt --extract "['init']" $testhost_backend
  check-output 0 "true"

  # test: host secrets can be decrypted with host key
  sops decrypt --extract "['age-key']" $testhost_backend >"$tmpkey"
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
  check-output 1 "incorrect root key"
}

@test "new root" {
  run "$script_name" -r 2 new age-key
  check-output 0 "completed"

  run "$script_name" -r 1 check age-key
  check-output 0 "completed"

  run "$script_name" -r 2 check age-key
  check-output 0 "completed"

  run "$script_name" -r 3 check age-key
  check-output 1 "not same"
}

@test "rotate root" {
  run "$script_name" -u testuser init age-key
  check-output 0 "completed"

  run "$script_name" -u testuser check age-key
  check-output 0 "completed"

  run "$script_name" -r 1 new age-key
  check-output 1 "can't rotate current"

  ROOT_KEY=2 run "$script_name" -u testuser check age-key
  check-output 1 "no key file"

  run "$script_name" -r 2 new age-key
  check-output 0 "completed"

  ROOT_KEY=2 run "$script_name" -u testuser check age-key
  check-output 0 "completed"

  ROOT_KEY=2 run "$script_name" -r 1 new age-key
  check-output 0 "completed"

  run "$script_name" -u testuser check age-key
  check-output 0 "completed"
}

@test "host new age-key" {
  PRIVATE_FILE=<(echo $age1) run "$script_name" -h testhost init
  check-output 0 "completed"

  run "$script_name" -h testhost check age-key
  check-output 0 "completed"

  run "$script_name" -h testhost new-private age-key
  check-output 0 "completed"

  run "$script_name" -h testhost check age-key
  check-output 1 "not same"
}

@test "host sync ssh-key" {
  run "$script_name" -h testhost init
  check-output 0 "completed"

  run "$script_name" -h testhost new ssh-key
  check-output 0 "completed"

  run "$script_name" -h testhost check ssh-key
  check-output 1 "not same"

  run "$script_name" -h testhost sync ssh-key
  check-output 0 "completed"

  run "$script_name" -h testhost check ssh-key
  check-output 0 "completed"
}

@test "host new ssh-key (no public)" {
  run "$script_name" -h testhost init
  check-output 0 "completed"

  run "$script_name" -h testhost new-private ssh-key
  check-output 0 "completed"

  run "$script_name" -h testhost check ssh-key
  check-output 1 "not same"
}

@test "host new wg-key" {
  run "$script_name" -h testhost init
  check-output 0 "completed"

  run "$script_name" -h testhost new wg-key
  check-output 0 "completed"

  run "$script_name" -h testhost check wg-key
  check-output 0 "completed"

  [[ -f $testroot/hosts/testhost/wg-key.pub ]]
}

@test "host new wg-key (mismatch)" {
  run "$script_name" -h testhost init
  check-output 0 "completed"

  run "$script_name" -h testhost new wg-key
  check-output 0 "completed"

  run "$script_name" -h testhost new-private wg-key
  check-output 0 "completed"

  run "$script_name" -h testhost check wg-key
  check-output 1 "not same"
}

@test "user new age-key" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new age-key
  check-output 0 "completed"

  run "$script_name" -u testuser check age-key
  check-output 0 "completed"
}

@test "user new age-key (mismatch)" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new age-key
  check-output 0 "completed"

  run "$script_name" -u testuser new-private age-key
  check-output 0 "completed"

  run "$script_name" -u testuser check age-key
  check-output 1 "not same"
}

@test "user new ssh-key" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new ssh-key
  check-output 0 "completed"

  run "$script_name" -u testuser check ssh-key
  check-output 0 "completed"

  [[ -f $testroot/users/testuser-ssh-key.pub ]]
}

@test "user new ssh-key (mismatch)" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new ssh-key
  check-output 0 "completed"

  run "$script_name" -u testuser new-private ssh-key
  check-output 0 "completed"

  run "$script_name" -u testuser check ssh-key
  check-output 1 "not same"
}

@test "user new ssh-key (no public)" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new-private ssh-key
  check-output 0 "completed"

  run "$script_name" -u testuser check ssh-key
  check-output 1 "not same"
}

@test "user new passwd" {
  run "$script_name" -u testuser init
  check-output 0 "completed"

  run "$script_name" -u testuser new passwd
  check-output 0 "completed"

  run "$script_name" -u testuser check passwd
  check-output 0 "completed"
}

@test "user new passwd (mismatch)" {
  run "$script_name" -u testuser init
  check-output 0 "age-key completed"

  run "$script_name" -u testuser new passwd

  run "$script_name" -u testuser new-private passwd
  check-output 0 "completed"

  run "$script_name" -u testuser check passwd
  check-output 1 "completed with errors"

  run "$script_name" -u testuser sync passwd
  check-output 0 "completed"

  run "$script_name" -u testuser check passwd
  check-output 0 "completed"
}

@test "domain new tls-cert" {
  run "$script_name" -d testdomain init
  check-output 0 "completed"

  run "$script_name" -d testdomain new tls-cert
  check-output 0 "completed"

  run "$script_name" -d testdomain check tls-cert
  check-output 0 "completed"

  [[ -f $testroot/domains/testdomain-tls-cert.pem ]]
}

@test "domain new tls-cert (mismatch)" {
  run "$script_name" -d testdomain init
  check-output 0 "completed"

  run "$script_name" -d testdomain new tls-cert
  check-output 0 "completed"

  run "$script_name" -d testdomain new-private tls-cert
  check-output 0 "completed"

  run "$script_name" -d testdomain check tls-cert
  check-output 1 "completed with errors"
}
