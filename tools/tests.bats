#!/usr/bin/env bats

setup() {
  export DEBUG=true
  echo "=== BEGIN SETUP ===" >&2
  testroot=$(mktemp -d)

  cp -R "./tools" "$testroot"

  cd "$testroot" && ./tools/manage.sh -u admin bootstrap

  mock_command() {
    local cmd_name=$1

    echo "#!/usr/bin/env bash" >"$testroot/bin/$cmd_name"
    echo "$2" >>"$testroot/bin/$cmd_name"
    chmod +x "$testroot/bin/$cmd_name"
  }
  mkdir -p "$testroot/bin"
  export PATH="$testroot/bin:$PATH"
  mock_command ssh-keyscan "echo \"ssh-ed25519 trust-me\""
  mock_command ssh "echo \"trust-me\""
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
  show "$1"
  ll=$(echo "$output" | tail -n 2 | head -n 1)

  if [[ $ll == *"$3"* && "$status" -eq $2 ]]; then
    return 0
  else
    echo "'$1' failed"
    echo "expected: $3 ($2)" >&2
    echo "got: $ll ($status)" >&2
    return 1
  fi
}

@test "no args" {
  run ./tools/manage.sh
  [ "$status" -eq 1 ]
}

@test "host new age-key" {
  run ./tools/manage.sh -h testhost init
  check-output "-h testhost init" 0 "host::init:: completed"

  run ./tools/manage.sh -h testhost new age-key
  check-output "-h testhost new age-key" 0 "host::new::age-key completed"

  run ./tools/manage.sh -h testhost check age-key
  check-output "-h testhost check age-key" 0 "host::check::age-key completed"
}

@test "host new age-key (mismatch)" {
  run ./tools/manage.sh -h testhost init
  check-output "-h testhost init" 0 "host::init:: completed"

  run ./tools/manage.sh -h testhost new age-key
  check-output "-h testhost new age-key" 0 "host::new::age-key completed"

  run ./tools/manage.sh -h testhost new-private age-key
  check-output "-h testhost new-private age-key" 0 "host::new-private::age-key completed"

  run ./tools/manage.sh -h testhost check age-key
  check-output "-h testhost check age-key" 1 "host::check::age-key completed with errors"
}

@test "host new age-key (no public)" {
  run ./tools/manage.sh -h testhost init
  check-output "-h testhost init" 0 "host::init:: completed"

  run ./tools/manage.sh -h testhost new-private age-key
  check-output "-h testhost new-private age-key" 0 "host::new-private::age-key completed"

  run ./tools/manage.sh -h testhost check age-key
  check-output "-h testhost check age-key" 1 "public key doesn't exist"
}

@test "host new ssh-key" {
  run ./tools/manage.sh -h testhost init
  check-output "-h testhost init" 0 "host::init:: completed"

  run ./tools/manage.sh -h testhost new ssh-key
  check-output "-h testhost new ssh-key" 0 "host::new::ssh-key completed"

  run ./tools/manage.sh -h testhost check ssh-key
  check-output "-h testhost check ssh-key" 0 "host::check::ssh-key completed"
}

@test "host new ssh-key (mismatch)" {
  run ./tools/manage.sh -h testhost init
  check-output "-h testhost init" 0 "host::init:: completed"

  run ./tools/manage.sh -h testhost new ssh-key
  check-output "-h testhost new ssh-key" 0 "host::new::ssh-key completed"

  run ./tools/manage.sh -h testhost new-private ssh-key
  check-output "-h testhost new-private ssh-key" 0 "host::new-private::ssh-key completed"

  run ./tools/manage.sh -h testhost check ssh-key
  check-output "-h testhost check ssh-key" 1 "host::check::ssh-key completed with errors"
}

@test "host new ssh-key (no public)" {
  run ./tools/manage.sh -h testhost init
  check-output "-h testhost init" 0 "host::init:: completed"

  run ./tools/manage.sh -h testhost new-private ssh-key
  check-output "-h testhost new-private ssh-key" 0 "host::new-private::ssh-key completed"

  run ./tools/manage.sh -h testhost check ssh-key
  check-output "-h testhost check ssh-key" 1 "public key doesn't exist"
}

@test "host new wg-key" {
  run ./tools/manage.sh -h testhost init
  check-output "-h testhost init" 0 "host::init:: completed"

  run ./tools/manage.sh -h testhost new wg-key
  check-output "-h testhost new wg-key" 0 "host::new::wg-key completed"

  run ./tools/manage.sh -h testhost check wg-key
  check-output "-h testhost new wg-key" 0 "host::check::wg-key completed"
}

@test "host new wg-key (mismatch)" {
  run ./tools/manage.sh -h testhost init
  check-output "-h testhost init" 0 "host::init:: completed"

  run ./tools/manage.sh -h testhost new wg-key
  check-output "-h testhost new wg-key" 0 "host::new::wg-key completed"

  run ./tools/manage.sh -h testhost new-private wg-key
  check-output "-h testhost new-private wg-key" 0 "host::new-private::wg-key completed"

  run ./tools/manage.sh -h testhost check wg-key
  check-output "-h testhost check wg-key" 1 "host::check::wg-key completed with errors"
}

@test "user new age-key" {
  run ./tools/manage.sh -u testuser init
  check-output "-u testuser init" 0 "user::init:: completed"

  run ./tools/manage.sh -u testuser new age-key
  check-output "-u testuser new age-key" 0 "user::new::age-key completed"

  run ./tools/manage.sh -u testuser check age-key
  check-output "-u testuser check age-key" 0 "user::check::age-key completed"
}

@test "user new age-key (mismatch)" {
  run ./tools/manage.sh -u testuser init
  check-output "-u testuser init" 0 "user::init:: completed"

  run ./tools/manage.sh -u testuser new age-key
  check-output "-u testuser new age-key" 0 "user::new::age-key completed"

  run ./tools/manage.sh -u testuser new-private age-key
  check-output "-u testuser new-private age-key" 0 "user::new-private::age-key completed"

  run ./tools/manage.sh -u testuser check age-key
  check-output "-u testuser check age-key" 1 "user::check::age-key completed with errors"
}

@test "user new age-key (no public)" {
  run ./tools/manage.sh -u testuser init
  check-output "-u testuser init" 0 "user::init:: completed"

  run ./tools/manage.sh -u testuser new-private age-key
  check-output "-u testuser new-private age-key" 0 "user::new-private::age-key completed"

  run ./tools/manage.sh -u testuser check age-key
  check-output "-u testuser check age-key" 1 "public key doesn't exist"
}

@test "user new ssh-key" {
  run ./tools/manage.sh -u testuser init
  check-output "-h testuser init" 0 "user::init:: completed"

  run ./tools/manage.sh -u testuser new ssh-key
  check-output "-h testuser new ssh-key" 0 "user::new::ssh-key completed"

  run ./tools/manage.sh -u testuser check ssh-key
  check-output "-h testuser check ssh-key" 0 "user::check::ssh-key completed"
}

@test "user new ssh-key (mismatch)" {
  run ./tools/manage.sh -u testuser init
  check-output "-h testuser init" 0 "user::init:: completed"

  run ./tools/manage.sh -u testuser new ssh-key
  check-output "-h testuser new ssh-key" 0 "user::new::ssh-key completed"

  run ./tools/manage.sh -u testuser new-private ssh-key
  check-output "-h testuser new ssh-key" 0 "user::new-private::ssh-key completed"

  run ./tools/manage.sh -u testuser check ssh-key
  check-output "-h testuser check ssh-key" 1 "user::check::ssh-key completed with errors"
}

@test "user new passwd" {
  run ./tools/manage.sh -u testuser init
  check-output "-h testuser init" 0 "user::init:: completed"

  run bash -c './tools/manage.sh -u testuser new passwd' <<EOF
mypassword
mypassword
EOF
  check-output "-h testuser new passwd" 0 "user::new::passwd completed"
}

@test "user new passwd (mismatch)" {
  run ./tools/manage.sh -u testuser init
  check-output "-h testuser init" 0 "user::init:: completed"

  run bash -c './tools/manage.sh -u testuser new passwd' <<EOF
mypassword
mypasswor
EOF

  check-output "-h testuser new passwd (mismatch)" 1 "password doesn't match"
}

@test "domain new tls-cert" {
  run ./tools/manage.sh -d testdomain init
  check-output "-h testdomain init" 0 "domain::init:: completed"

  run ./tools/manage.sh -d testdomain new tls-cert
  check-output "-h testdomain new tls-cert" 0 "domain::new::tls-cert completed"

  run ./tools/manage.sh -d testdomain check tls-cert
  check-output "-h testdomain check tls-cert" 0 "domain::check::tls-cert completed"
}

@test "domain new tls-cert (mismatch)" {
  run ./tools/manage.sh -d testdomain init
  check-output "-h testdomain init" 0 "domain::init:: completed"

  run ./tools/manage.sh -d testdomain new tls-cert
  check-output "-h testdomain new tls-cert" 0 "domain::new::tls-cert completed"

  run ./tools/manage.sh -d testdomain new-private tls-cert
  check-output "-h testdomain new-private tls-cert" 0 "domain::new-private::tls-cert completed"

  run ./tools/manage.sh -d testdomain check tls-cert
  check-output "-h testdomain check tls-cert" 1 "domain::check::tls-cert completed with errors"
}
