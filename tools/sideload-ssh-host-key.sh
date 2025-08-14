#!/usr/bin/env bash
key1=/etc/ssh/ssh_host_ed25519_key
key2=/etc/ssh/ssh_host_ed25519_key-
cmp -s pk "$key2" && {
  echo "Error: Two identical keys not allowed"
  exit 1
}
cp "$key1" "$key2"
cp pk "$key1"
chmod 600 "$key1"
chown root:root $key1
rm -f pk
echo ""
echo "Key '$key1' succesfully deployed!"
echo "Rebuild me now or suffer the consequences."
echo ""
systemctl restart sshd
