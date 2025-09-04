#!/usr/bin/env bash
echo "testhost.local $(ssh-keygen -y -f <(echo "$1"))"
