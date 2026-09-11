#!/usr/bin/env bats

setup() {
  # Mock the lxc command by creating a function that logs its calls
  export LXC_MOCK_LOG="$(mktemp)"

  lxc() {
    echo "lxc $@" >> "$LXC_MOCK_LOG"
  }
  export -f lxc

  # Source the script
  source "${BATS_TEST_DIRNAME}/../scripts/setup.sh"
}

teardown() {
  rm -f "$LXC_MOCK_LOG"
}

@test "launch_and_limit creates container and sets limits correctly" {
  run launch_and_limit "test-container" 4 "8GB"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Provisioning test-container: 4 cores, 8GB RAM"* ]]

  # Read mock log
  run cat "$LXC_MOCK_LOG"

  # Check if lxc commands were called correctly
  [[ "${lines[0]}" == "lxc launch ubuntu:20.04 test-container" ]]
  [[ "${lines[1]}" == "lxc config set test-container limits.cpu 4" ]]
  [[ "${lines[2]}" == "lxc config set test-container limits.memory 8GB" ]]
}

@test "launch_and_limit fails if arguments are missing" {
  run launch_and_limit "test-container-2"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Error: launch_and_limit requires 3 arguments"* ]]

  # Read mock log to confirm lxc commands were not executed
  run cat "$LXC_MOCK_LOG"
  [ -z "$output" ]
}

@test "launch_and_limit works with edge case inputs" {
  run launch_and_limit "special_name-1" "1.5" "512MB"

  [ "$status" -eq 0 ]

  # Read mock log
  run cat "$LXC_MOCK_LOG"
  [[ "${lines[0]}" == "lxc launch ubuntu:20.04 special_name-1" ]]
  [[ "${lines[1]}" == "lxc config set special_name-1 limits.cpu 1.5" ]]
  [[ "${lines[2]}" == "lxc config set special_name-1 limits.memory 512MB" ]]
}
