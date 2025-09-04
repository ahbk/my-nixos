#!/usr/bin/env bash
export LUKS_DEVICE=
export KEY_FILE=$1
./tools/keyservice.sh "$2"
