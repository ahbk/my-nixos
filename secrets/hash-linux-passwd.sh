#!/usr/bin/env bash

# Path to the private SSH key used for decryption
PRIVATE_KEY="./id_ed25519"

# Iterate over all files matching linux-passwd-plain-*
for plain_file in linux-passwd-plain-*.age; do
  # Extract the username from the filename
  username=$(basename "$plain_file" .age | sed 's/linux-passwd-plain-//')
  
  # Decrypt the file to get the plain password
  plain_password=$(agenix -d "$plain_file" -i "$PRIVATE_KEY")
  
  # Hash the password with mkpasswd
  hashed_password=$(echo "$plain_password" | mkpasswd -sm bcrypt)
  
  # Create the new hashed password filename
  hashed_file="linux-passwd-hashed-${username}.age"
  
  # Encrypt the hashed password and save it to the new file
  echo "$hashed_password" | agenix -e "$hashed_file" -i "$PRIVATE_KEY"
  
  echo "Processed $plain_file -> $hashed_file"
done
