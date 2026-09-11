#!/bin/bash
set -e

# Function to launch and configure LXC containers
launch_and_limit() {
  local name=$1
  local cores=$2
  local memory=$3
  echo "Provisioning $name: $cores cores, $memory RAM"
  lxc launch ubuntu:20.04 "$name"
  lxc config set "$name" limits.cpu "$cores"
  lxc config set "$name" limits.memory "$memory"
}

main() {
  # Update package lists and install ZFS
  apt-get update
  apt-get install -y zfsutils-linux

  # Prepare the second 1TB SATA drive (/dev/sdb) for ZFS
  # Note: /dev/sda is the primary OS drive.
  wipefs -a /dev/sdb
  zpool create -f lxd-pool /dev/sdb

  # Initialize LXD with the ZFS storage pool
  # LXD is pre-installed as a snap on Ubuntu 20.04
  lxd init --auto --storage-pool lxd-pool --storage-backend zfs

  # Wait for LXD daemon to be fully initialized
  while ! lxc info > /dev/null 2>&1; do
    echo "Waiting for LXD to start..."
    sleep 5
  done

  # Deploy 9 isolated containers as per tier requirements
  local tiers=("ultra:8:12GB" "pro:4:8GB" "starter:2:4GB")
  for tier_info in "${tiers[@]}"; do
    IFS=":" read -r tier cores memory <<< "$tier_info"
    for i in {1..3}; do
      launch_and_limit "${tier}-${i}" "$cores" "$memory"
    done
  done

  echo "Deployment of 9 containers completed successfully."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
