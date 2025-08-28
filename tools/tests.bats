#!/usr/bin/env bats

unset SOPS_AGE_KEY_FILE

setup() {
  export LOG_LEVEL=debug
  echo "=== BEGIN SETUP ===" >&2
  testroot=$BATS_TEST_TMPDIR/testroot
  mkdir -p "$testroot"
  wrong_age_key=AGE-SECRET-KEY-1V782VQAQT6QJPARYTCD8CLES04Q83V068FRFDWG02HGLE96U93FSVACDKF
  right_age_key=AGE-SECRET-KEY-1DJDMVRRC7UNF8HSKVSGQCWFNMJ5HTRT6HT2MDML9JZ54GCW8TYNSSWWL8D
  testhost_age_key=AGE-SECRET-KEY-1L0EJY3FLSYHDE46Y80F0KLUKUWP6V3J340UR7G2GWNFGXJQ0P6ZQ6X37TN

  testhost_ssh_key="-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACDEE3csx1IE4hhJQOzYQh7xZ8iZY6wj1C1xYp2DjxjmOAAAAKDYIpSm2CKU
pgAAAAtzc2gtZWQyNTUxOQAAACDEE3csx1IE4hhJQOzYQh7xZ8iZY6wj1C1xYp2DjxjmOA
AAAEA4YkpxaWCNi2sH27/j3HB+cMO81OHPrAzAeD15B1N9BcQTdyzHUgTiGElA7NhCHvFn
yJljrCPULXFinYOPGOY4AAAAF3Rlc3R1c2VyQHRlc3Rob3N0LmxvY2FsAQIDBAUG
-----END OPENSSH PRIVATE KEY-----"

  ssh_ed25519_pub="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMQTdyzHUgTiGElA7NhCHvFnyJljrCPULXFinYOPGOY4 testuser@testhost.local"

  cp -R "./tools" "$testroot"
  script_name=./tools/manage-entities.sh

  cd "$testroot" && PRIVATE_FILE=<(echo "$right_age_key") "$script_name" -r 1 new age-key

  echo "$testhost_age_key" >./testhost-age-key
  echo "$testhost_ssh_key" >./testhost-ssh-key

  mock_command() {
    local cmd_name=$1

    echo "#!/usr/bin/env bash" >"$testroot/bin/$cmd_name"
    echo "$2" >>"$testroot/bin/$cmd_name"
    chmod +x "$testroot/bin/$cmd_name"
  }
  mkdir -p "$testroot/bin"
  export PATH="$testroot/bin:$PATH"
  mock_command ssh-keyscan "echo \"testhost.local $ssh_ed25519_pub\""
  mock_command ssh "cat ./testhost-age-key"
  echo "=== END SETUP ===" >&2
}

teardown() {
  rm -r "$testroot"
}

show() {
  echo "=== OUTPUT $1 ===" >&2
  echo "$output" >&2
  echo "=== STATUS: $status ===" >&2
}

check-output() {
  show "$BATS_TEST_COMMAND"
  ll=$(echo "$output" | tail -n 1)

  if [[ $ll == *"$2"* && "$status" -eq $1 ]]; then
    return 0
  else
    echo "'$BATS_RUN_COMMAND' failed"
    echo "expected: $2 ($1)" >&2
    echo "got: $ll ($status)" >&2
    return 1
  fi
}

@test "setup works" {
  key_file=$(yq ".key-file" .sops.yaml)
  [[ "$key_file" == "./keys.txt" ]]
  cat "$key_file"
  public_key=$(age-keygen -y <"$key_file")
  [[ $public_key == $(echo "$right_age_key" | age-keygen -y) ]]
  root_anchor=$(yq ".entities.root-1" .sops.yaml)
  echo "public key: $public_key"
  echo "root anchor: $root_anchor"
  [[ $public_key == "$root_anchor" ]]
}

@test "no args" {
  run "$script_name"
  [ "$status" -eq 1 ]
}

@test "init host works" {
  local secrets_file="hosts/testhost/secrets.yaml"
  run "$script_name" -h testhost init
  check-output 0 "host::init::age-key completed"
  export SOPS_AGE_KEY_FILE
  # host secrets can be decrypted with root key
  SOPS_AGE_KEY_FILE=./keys.txt
  init=$(sops decrypt --extract "['init']" $secrets_file)
  [[ $init == true ]]

  # host secrets can be decrypted with host key
  sops decrypt --extract "['age-key']" $secrets_file >./host-key.txt
  SOPS_AGE_KEY_FILE=./host-key.txt
  init=$(sops decrypt --extract "['init']" $secrets_file)
  [[ $init == true ]]
}

@test "not authorized" {
  run "$script_name" -h testhost init
  check-output 0 "host::init::age-key completed"

  echo "$wrong_age_key" >"./keys.txt"

  run "$script_name" -h testhost new age-key
  check-output 1 "root key not authorized"
}

@test "new root" {
  run "$script_name" -r 2 new age-key
  check-output 0 "root::new::age-key completed"

  run "$script_name" -r 1 check age-key
  check-output 0 "root::check::age-key completed"

  run "$script_name" -r 2 check age-key
  check-output 0 "root::check::age-key completed"

  run "$script_name" -r 3 check age-key
  check-output 1 "root::check::age-key completed with errors"
}

@test "new root (conflict)" {
  run "$script_name" -r 1 new age-key
  check-output 1 "insert-anchor failed"
}

@test "host new age-key" {
  PRIVATE_FILE=./testhost-age-key run "$script_name" -h testhost init
  check-output 0 "host::init::age-key completed"

  run "$script_name" -h testhost check age-key
  check-output 0 "host::check::age-key completed"
}

@test "host new age-key (mismatch)" {
  PRIVATE_FILE=./testhost-age-key run "$script_name" -h testhost init
  check-output 0 "host::init::age-key completed"

  run "$script_name" -h testhost new-private age-key
  check-output 0 "host::new-private::age-key completed"

  run "$script_name" -h testhost check age-key
  check-output 1 "host::check::age-key completed with errors"
}

@test "host sync ssh-key" {
  run "$script_name" -h testhost init
  check-output 0 "host::init::age-key completed"

  run "$script_name" -h testhost new ssh-key
  check-output 0 "host::new::ssh-key completed"

  run "$script_name" -h testhost check ssh-key
  check-output 1 "host::check::ssh-key completed"

  run "$script_name" -h testhost sync ssh-key
  check-output 0 "host::sync::ssh-key completed"

  run "$script_name" -h testhost check ssh-key
  check-output 0 "host::check::ssh-key completed"
}

@test "host new ssh-key (no public)" {
  run "$script_name" -h testhost init
  check-output 0 "host::init::age-key completed"

  run "$script_name" -h testhost new-private ssh-key
  check-output 0 "host::new-private::ssh-key completed"

  run "$script_name" -h testhost check ssh-key
  check-output 1 "public key doesn't exist"
}

@test "host new wg-key" {
  run "$script_name" -h testhost init
  check-output 0 "host::init::age-key completed"

  run "$script_name" -h testhost new wg-key
  check-output 0 "host::new::wg-key completed"

  run "$script_name" -h testhost check wg-key
  check-output 0 "host::check::wg-key completed"

  [[ -f $testroot/hosts/testhost/wg-key.pub ]]
}

@test "host new wg-key (mismatch)" {
  run "$script_name" -h testhost init
  check-output 0 "host::init::age-key completed"

  run "$script_name" -h testhost new wg-key
  check-output 0 "host::new::wg-key completed"

  run "$script_name" -h testhost new-private wg-key
  check-output 0 "host::new-private::wg-key completed"

  run "$script_name" -h testhost check wg-key
  check-output 1 "host::check::wg-key completed with errors"
}

@test "user new age-key" {
  run "$script_name" -u testuser init
  check-output 0 "user::init::age-key completed"

  run "$script_name" -u testuser new age-key
  check-output 0 "user::new::age-key completed"

  run "$script_name" -u testuser check age-key
  check-output 0 "user::check::age-key completed"
}

@test "user new age-key (mismatch)" {
  run "$script_name" -u testuser init
  check-output 0 "user::init::age-key completed"

  run "$script_name" -u testuser new age-key
  check-output 0 "user::new::age-key completed"

  run "$script_name" -u testuser new-private age-key
  check-output 0 "user::new-private::age-key completed"

  run "$script_name" -u testuser check age-key
  check-output 1 "user::check::age-key completed with errors"
}

@test "user new ssh-key" {
  run "$script_name" -u testuser init
  check-output 0 "user::init::age-key completed"

  run "$script_name" -u testuser new ssh-key
  check-output 0 "user::new::ssh-key completed"

  run "$script_name" -u testuser check ssh-key
  check-output 0 "user::check::ssh-key completed"

  [[ -f $testroot/users/testuser-ssh-key.pub ]]
}

@test "user new ssh-key (mismatch)" {
  run "$script_name" -u testuser init
  check-output 0 "user::init::age-key completed"

  run "$script_name" -u testuser new ssh-key
  check-output 0 "user::new::ssh-key completed"

  run "$script_name" -u testuser new-private ssh-key
  check-output 0 "user::new-private::ssh-key completed"

  run "$script_name" -u testuser check ssh-key
  check-output 1 "user::check::ssh-key completed with errors"
}

@test "user new ssh-key (no public)" {
  run "$script_name" -u testuser init
  check-output 0 "user::init::age-key completed"

  run "$script_name" -u testuser new-private ssh-key
  check-output 0 "user::new-private::ssh-key completed"

  run "$script_name" -u testuser check ssh-key
  check-output 1 "public key doesn't exist"
}

@test "user new passwd" {
  run "$script_name" -u testuser init
  check-output 0 "user::init::age-key completed"

  run "$script_name" -u testuser new passwd
  check-output 0 "user::new::passwd completed"

  run "$script_name" -u testuser check passwd
  check-output 0 "user::check::passwd completed"
}

@test "user new passwd (mismatch)" {
  run "$script_name" -u testuser init
  check-output 0 "user::init::age-key completed"

  run "$script_name" -u testuser new passwd

  run "$script_name" -u testuser new-private passwd
  check-output 0 "user::new-private::passwd completed"

  run "$script_name" -u testuser check passwd
  check-output 1 "user::check::passwd completed with errors"

  run "$script_name" -u testuser sync passwd
  check-output 0 "user::sync::passwd completed"

  run "$script_name" -u testuser check passwd
  check-output 0 "user::check::passwd completed"
}

@test "domain new tls-cert" {
  run "$script_name" -d testdomain init
  check-output 0 "domain::init::age-key completed"

  run "$script_name" -d testdomain new tls-cert
  check-output 0 "domain::new::tls-cert completed"

  run "$script_name" -d testdomain check tls-cert
  check-output 0 "domain::check::tls-cert completed"

  [[ -f $testroot/domains/testdomain-tls-cert.pem ]]
}

@test "domain new tls-cert (mismatch)" {
  run "$script_name" -d testdomain init
  check-output 0 "domain::init::age-key completed"

  run "$script_name" -d testdomain new tls-cert
  check-output 0 "domain::new::tls-cert completed"

  run "$script_name" -d testdomain new-private tls-cert
  check-output 0 "domain::new-private::tls-cert completed"

  run "$script_name" -d testdomain check tls-cert
  check-output 1 "domain::check::tls-cert completed with errors"
}
