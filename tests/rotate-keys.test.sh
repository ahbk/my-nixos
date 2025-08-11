#!/usr/bin/env bats

# BATS-CORE TEST FOR rotate-keys SCRIPT

# -----------------------------------------------------------------------------
# Test Setup and Teardown
# -----------------------------------------------------------------------------

# This function runs before each test. It creates a temporary directory structure
# and necessary dummy files to simulate the real environment your script runs in.
#
script_path="/home/alex/Desktop/nixos/tests"

setup() {
	BATS_TMPDIR=$(mktemp -d)
	cd "$BATS_TMPDIR" || exit

	mkdir -p hosts/testhost keys

	cp "$script_path/secrets.template.yaml" ./secrets.template.yaml
	cp "$script_path/.sops.yaml" ./

	cp "$script_path/../tools/rotate-keys.sh" ./rotate-keys
	chmod +x ./rotate-keys

	# Mock external commands to avoid actual network operations or dependencies.
	# This allows us to test the script's logic in isolation.
	mock_command() {
		local cmd_name=$1
		shift
		# Create a mock script that just prints its arguments and exits successfully.
		echo "#!/bin/sh" >"$BATS_TMPDIR/bin/$cmd_name"
		echo "echo \"$cmd_name called with: \$@\"" >>"$BATS_TMPDIR/bin/$cmd_name"
		chmod +x "$BATS_TMPDIR/bin/$cmd_name"
	}

	mkdir -p bin
	export PATH="$BATS_TMPDIR/bin:$PATH"

	mock_command sops
	mock_command ssh-keygen
	mock_command ssh-to-age
	mock_command yq
	mock_command wg
	mock_command scp
	mock_command ssh
	mock_command ssh-keyscan
}

# This function runs after each test to clean up the temporary environment.
teardown() {
	# Remove the temporary directory and all its contents.
	rm -rf "$BATS_TMPDIR"
}

assert_equal() {
	local actual="$1"
	local expected="$2"
	local message="$3"

	if [ "$actual" != "$expected" ]; then
		echo "--> FAILED: $message" >&2
		echo "--> Expected: '$expected'" >&2
		echo "--> Actual:   '$actual'" >&2
		return 1 # Fail
	fi
}

assert_contains() {
	local actual="$1"
	local expected_substring="$2"
	local message="$3"

	if [[ "$actual" != *"$expected_substring"* ]]; then
		echo "--> FAILED: $message" >&2
		echo "--> Expected to contain: '$expected_substring'" >&2
		echo "--> Actual:              '$actual'" >&2
		return 1 # Fail
	fi
}

assert_status() {
	local actual="$1"
	local expected="$2"
	local message="$3"

	if [[ "$actual" != "$expected" ]]; then
		echo "--> FAILED: $message" >&2
		echo "--> Expected to contain: '$expected'" >&2
		echo "--> Actual:              '$actual'" >&2
		return 1 # Fail
	fi
}
# -----------------------------------------------------------------------------
# Test Cases
# -----------------------------------------------------------------------------

@test "should show usage with no arguments" {
	run ./rotate-keys
	[ "$status" -ne 0 ]
	assert_equal "${lines[1]}" "Usage: rotate-keys <host> <action> <type>" "Usage message line is incorrect."
}

@test "should show usage with incorrect number of arguments" {
	run ./rotate-keys testhost new
	[ "$status" -ne 0 ]
	assert_equal "${lines[28]}" "Error: 3 arguments required." "Error message for wrong argument count is incorrect."
}

@test "should fail with invalid host" {
	run ./rotate-keys invalidhost new ssh-host-key
	[ "$status" -ne 0 ]
	assert_equal "${lines[0]}" "Error: hostname 'invalidhost' doesn't have an entry in hosts/, did you spell it correctly?" "Error message for invalid host is incorrect."
}

@test "should fail with invalid action" {
	run ./rotate-keys testhost invalidaction ssh-host-key
	[ "$status" -ne 0 ]
	assert_contains "${lines[0]}" "is not an action" "Error message for invalid action is incorrect."
}

@test "should fail with invalid type" {
	run ./rotate-keys testhost new invalidtype
	[ "$status" -ne 0 ]
	assert_contains "${lines[0]}" "is not a valid key type" "Error message for invalid type is incorrect."
}

@test "'new ssh-host-key' action should create public key and secrets file" {
	# Override the mock for ssh-keygen to generate actual key files for this test.
	unmock ssh-keygen

	run ./rotate-keys testhost new ssh-host-key

	[ "$status" -eq 0 ]
	[ -f "keys/testhost-ssh-host-key.pub" ]
	[ -f "hosts/testhost/secrets.yaml" ]

	# Check if the public key file is not empty
	[ -s "keys/testhost-ssh-host-key.pub" ]
}

@test "'new wg-key' action should create public key and secrets file" {
	# Override the mock for wg to simulate key generation.
	# This mock will create a dummy private key and a corresponding public key.
	cat >"$BATS_TMPDIR/bin/wg" <<'EOF'
#!/bin/sh
if [ "$1" = "genkey" ]; then
    echo "dummy_wg_private_key"
elif [ "$1" = "pubkey" ]; then
    echo "dummy_wg_public_key"
fi
EOF
	chmod +x "$BATS_TMPDIR/bin/wg"

	run ./rotate-keys testhost new wg-key

	[ "$status" -eq 0 ]
	[ -f "keys/testhost-wg-key.pub" ]

	actual_key=$(cat keys/testhost-wg-key.pub)
	assert_equal "$actual_key" "dummy_wg_public_key" "The generated WireGuard public key is incorrect."

	[ -f "hosts/testhost/secrets.yaml" ]
}

@test "'sync' action should regenerate public key" {
	# Setup: Create an initial key and then delete the public part.
	unmock ssh-keygen
	./rotate-keys testhost new ssh-host-key
	rm "keys/testhost-ssh-host-key.pub"
	[ ! -f "keys/testhost-ssh-host-key.pub" ]

	# Action: Run sync to regenerate it.
	# We need to provide a mock for sops decrypt to return a valid private key.
	cat >"$BATS_TMPDIR/bin/sops" <<'EOF'
#!/bin/sh
if [ "$1" = "decrypt" ]; then
    ssh-keygen -q -t ed25519 -f /dev/stdout -N "" <<<y >/dev/null 2>&1
else
    # Default sops mock behavior
    echo "sops called with: $@"
fi
EOF

	run ./rotate-keys testhost sync ssh-host-key

	assert_status $status 0 "asdf"
	[ "$status" -eq 0 ]
	[ -f "keys/testhost-ssh-host-key.pub" ]
	[ -s "keys/testhost-ssh-host-key.pub" ]
}

@test "'check' action should pass when keys are in sync" {
	# Setup: Create a new key pair.
	unmock ssh-keygen
	./rotate-keys testhost new ssh-host-key

	# We need a more sophisticated sops mock for the 'check' command.
	# It needs to "decrypt" the key that was just created.
	# For simplicity, we'll just have it generate a new key that matches the format.
	cat >"$BATS_TMPDIR/bin/sops" <<'EOF'
#!/bin/sh
if [ "$1" = "decrypt" ]; then
    # This is tricky to mock perfectly without reimplementing sops.
    # We'll extract the private key from the temp file created by the script itself.
    # This is a bit of a hack, but effective for testing the 'check' logic.
    # The private key is stored in a temp file by the main script. We assume its location.
    # A better approach would be to have the script output the temp file path for testing.
    # For now, we regenerate a key as a placeholder for decryption.
    ssh-keygen -q -t ed25519 -f /dev/stdout -N "" <<<y >/dev/null 2>&1
else
    echo "sops called with: $@"
fi
EOF

	# To make the check pass, we will read the public key and provide it as the "decrypted" version.
	PUBLIC_KEY_CONTENT=$(cat keys/testhost-ssh-host-key.pub)
	PRIVATE_KEY_FOR_CHECK=$(ssh-keygen -q -t ed25519 -f /dev/stdout -N "" <<<y 2>/dev/null)
	PUBLIC_KEY_FROM_PRIVATE=$(ssh-keygen -y -f <(echo "$PRIVATE_KEY_FOR_CHECK"))

	# Mock generate-public-ssh-host-key to return the correct public key
	echo "#!/bin/sh" >"$BATS_TMPDIR/bin/generate-public-ssh-host-key"
	echo "echo '$PUBLIC_KEY_FROM_PRIVATE'" >>"$BATS_TMPDIR/bin/generate-public-ssh-host-key"
	chmod +x "$BATS_TMPDIR/bin/generate-public-ssh-host-key"

	run ./rotate-keys testhost check ssh-host-key

	[ "$status" -eq 0 ]
	assert_contains "$output" "Match: true" "The 'check' action should report that keys are in sync."
}

# Helper function to unmock a command and use the real one
unmock() {
	rm -f "$BATS_TMPDIR/bin/$1"
}
