#!/usr/bin/env bash

# Create a temporary directory
temp=$(mktemp -d)

# Function to cleanup temporary directory on exit
cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

# Create the directory where sshd expects to find the host keys
install -d -m755 "$temp/etc/ssh"

# Decrypt your private key from the password store and copy it to the temporary directory
sops decrypt --extract '["ssh-host-key"]' ./hosts/"$1"/secrets.yaml >"$temp/etc/ssh/ssh_host_ed25519_key"

# Set the correct permissions so sshd will accept the key
chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"

# Install NixOS to the host system with our secrets
nixos-anywhere \
  --disk-encryption-keys /secret.key <(sops decrypt --extract '["luks-secret-key"]' hosts/"$1"/secrets.yaml) \
  --generate-hardware-config nixos-facter hosts/"$1"/facter.json \
  --extra-files "$temp" \
  --flake ".#$1" \
  --target-host root@"$1".kompismoln.se
