#!/usr/bin/env bash

# A script to rotate an ed25519 SSH host key and update all references to it
# in the sops configuration.

set -e
set -o pipefail
set -u

# --- Configuration ---
SSH_KEY_TYPE="ed25519"
SSH_KEY_COMMENT="host-key-$(date +%Y-%m-%d)"
FORCE_NEW_KEY=false

# --- Functions ---

# Function to display usage information
usage() {
  echo "Usage: $0 [-f] <hostname>"
  echo ""
  echo "Rotates an SSH host key and updates sops configuration."
  echo ""
  echo "Arguments:"
  echo "  <hostname>              : Name of the host anchor in .sops.yaml (e.g., 'helsinki')."
  echo ""
  echo "Options:"
  echo "  -f                      : Force generation of a new private key. If omitted, the script"
  echo "                          : will regenerate public keys from the existing encrypted private key."
}

# Function to check for required command-line tools
check_dependencies() {
  local missing=0
  for cmd in ssh-keygen sops yq ssh-to-age; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "Error: Required command '$cmd' not found in PATH." >&2
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    exit 1
  fi
}

# --- Main Script Logic ---

# 1. Parse Command-Line Arguments
while getopts "f" opt; do
  case "$opt" in
    f)
      FORCE_NEW_KEY=true
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

# 2. Validate Inputs
if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

HOST_NAME="$1"
OUTPUT_FILE_BASE="keys/ssh-host-$HOST_NAME"
ENCRYPTED_PRIVATE_KEY="$OUTPUT_FILE_BASE.enc"

if [ ! -f ".sops.yaml" ]; then
    echo "Error: '.sops.yaml' not found in the current directory." >&2
    echo "Sops needs this file to know which keys to encrypt for." >&2
    exit 1
fi

# Check for dependencies
check_dependencies

# Ensure the output directory for keys exists
mkdir -p "keys"

# 3. Create a secure temporary directory
# This directory will hold unencrypted key material.
# 'mktemp -d' creates a directory with secure (user-only) permissions.
TMP_DIR=$(mktemp -d)

# 4. Set up a trap to ensure the temporary directory is cleaned up on exit
# This runs whether the script succeeds, fails, or is interrupted.
trap 'echo "Cleaning up temporary files..."; rm -rf "$TMP_DIR"' EXIT

echo "Temporary directory created at: $TMP_DIR"
TEMP_SSH_PRIVATE_KEY="$TMP_DIR/ssh_host_key"

# 5. Generate or Decrypt the SSH Private Key
if [ "$FORCE_NEW_KEY" = true ]; then
  # --- Force Mode: Generate a new key pair ---
  echo "--- Mode: Forcing new key generation (-f) ---"
  echo "Generating new $SSH_KEY_TYPE SSH key..."
  ssh-keygen -t "$SSH_KEY_TYPE" -f "$TEMP_SSH_PRIVATE_KEY" -N "" -C "$SSH_KEY_COMMENT"
  echo "New SSH key generated in temporary directory."

  echo "Encrypting the new private key with sops..."
  # Set the SOPS_AGE_KEY_FILE env var for sops to pick up the key
  sops encrypt --filename-override ssh-host-key "$TEMP_SSH_PRIVATE_KEY" > "$ENCRYPTED_PRIVATE_KEY"
  echo "Encrypted private key saved to '$ENCRYPTED_PRIVATE_KEY'"

else
  # --- Default Mode: Use existing key ---
  echo "--- Mode: Using existing key ---"
  if [ ! -f "$ENCRYPTED_PRIVATE_KEY" ]; then
    echo "Error: Encrypted key '$ENCRYPTED_PRIVATE_KEY' not found." >&2
    echo "Run with -f to generate it for the first time." >&2
    exit 1
  fi
  echo "Decrypting existing private key '$ENCRYPTED_PRIVATE_KEY'..."
  sops decrypt "$ENCRYPTED_PRIVATE_KEY" > "$TEMP_SSH_PRIVATE_KEY"
  # Ensure the decrypted key has the correct permissions
  chmod 600 "$TEMP_SSH_PRIVATE_KEY"
  echo "Private key decrypted to temporary directory."
fi

PRIVATE_AGE_KEY=$(cat $TEMP_SSH_PRIVATE_KEY | ssh-to-age -private-key)
echo "Private age key: $PRIVATE_AGE_KEY"

# 6. Generate Public Keys from the (now unencrypted) Private Key
echo "Generating public key files from the private key..."
ssh-keygen -y -f "$TEMP_SSH_PRIVATE_KEY" > "$OUTPUT_FILE_BASE.pub"
echo "SSH public key saved to '$OUTPUT_FILE_BASE.pub'"

cat "$OUTPUT_FILE_BASE.pub" | ssh-to-age > "$OUTPUT_FILE_BASE.age.pub"
echo "Age public key saved to '$OUTPUT_FILE_BASE.age.pub'"

# 7. Update .sops.yaml with the new Age Public Key
echo "Updating .sops.yaml and secrets..."

NEW_KEY=$(cat "$OUTPUT_FILE_BASE.age.pub") yq -i "(.keys[] | select(anchor == \"host_$HOST_NAME\")) |= env(NEW_KEY)" .sops.yaml

sops updatekeys -y ./secrets/*.yaml

echo ".sops.yaml has been updated successfully."
echo ""
echo "--- Rotation Complete for host '$HOST_NAME' ---"

exit 0
