#!/usr/bin/env bats

@test "addition using bc" {
	result="2+2"
	[[ "$result" -eq "2+2" ]]
}

@test "addition using dc" {
	result="$(echo 2 2+p | dc)"
	[ "$result" -eq 4 ]
}
