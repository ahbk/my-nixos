#!/usr/bin/env bash
set -e

tmpfile=$(mktemp)

sudo cp "$1" "$tmpfile"
sudo rm -f "$1"
sudo mount --bind "$tmpfile" "$1"

echo "Temporary $1 ($tmpfile) ready. Edit $1 freely."
