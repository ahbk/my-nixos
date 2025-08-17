#!/usr/bin/env bats

setup() {
  echo "=== BEGIN SETUP ===" >&2
  testroot=$(mktemp -d)

  cp -R "./tools" "$testroot"

  cd "$testroot" && ./tools/secrets.sh bootstrap admin

  mock_command() {
    local cmd_name=$1

    echo "#!/usr/bin/env bash" >"$testroot/bin/$cmd_name"
    echo "echo \"ssh-ed25519 trust-me\"" >>"$testroot/bin/$cmd_name"
    chmod +x "$testroot/bin/$cmd_name"
  }
  mkdir -p "$testroot/bin"
  export PATH="$testroot/bin:$PATH"
  mock_command ssh-keyscan
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
  [[ "$status" -eq $2 ]]
  ll=$(echo "$output" | tail -n 2 | head -n 1)

  if [[ $ll == *"$3"* ]]; then
    return 0
  else
    echo "'$1' failed"
    echo "expected: $3" >&2
    echo "got: $ll" >&2
    return 1
  fi
}

@test "no args" {
  run ./tools/secrets.sh
  [ "$status" -eq 1 ]
}

@test "host new ssh-key" {
  run ./tools/secrets.sh -h testhost init
  check-output "-h testhost init" 0 "secrets file created"

  run ./tools/secrets.sh -h testhost new ssh-key
  check-output "-h testhost new ssh-key" 0 "host::new::ssh-key completed"

  run ./tools/secrets.sh -h testhost check ssh-key
  check-output "-h testhost check ssh-key" 0 "host::check::ssh-key completed"
}

@test "host new wg-key" {
  run ./tools/secrets.sh -h testhost init
  check-output "-h testhost init" 0 "secrets file created"

  run ./tools/secrets.sh -h testhost new wg-key
  check-output "-h testhost new wg-key" 0 "host::new::wg-key completed"

  run ./tools/secrets.sh -h testhost check wg-key
  check-output "-h testhost new wg-key" 0 "host::check::wg-key completed"
}

@test "user new ssh-key" {
  run ./tools/secrets.sh -u testuser init
  check-output "-h testuser init" 0 "secrets file created"

  run ./tools/secrets.sh -u testuser new ssh-key
  check-output "-h testuser new wg-key" 0 "user::new::ssh-key completed"
}

@test "user new passwd" {
  run ./tools/secrets.sh -u testuser init
  check-output "-h testuser init" 0 "secrets file created"

  run bash -c './tools/secrets.sh -u testuser new passwd' <<EOF
mypassword
mypassword
EOF
  check-output "-h testuser new wg-key" 0 "user::new::passwd completed"
}

@test "domain new tls-cert" {
  run ./tools/secrets.sh -d testdomain init
  check-output "-h testdomain init" 0 "secrets file created"

  run ./tools/secrets.sh -d testdomain new tls-cert
  check-output "-h testdomain new tls-cert" 0 "domain::new::tls-cert completed"
}
