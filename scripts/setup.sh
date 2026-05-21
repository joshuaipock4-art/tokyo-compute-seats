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
  # 3x Ultra instances (8 cores / 12GB RAM)
  launch_and_limit "ultra-1" 8 12GB
  launch_and_limit "ultra-2" 8 12GB
  launch_and_limit "ultra-3" 8 12GB

  # 3x Pro instances (4 cores / 8GB RAM)
  launch_and_limit "pro-1" 4 8GB
  launch_and_limit "pro-2" 4 8GB
  launch_and_limit "pro-3" 4 8GB

  # 3x Starter instances (2 cores / 4GB RAM)
  launch_and_limit "starter-1" 2 4GB
  launch_and_limit "starter-2" 2 4GB
  launch_and_limit "starter-3" 2 4GB

  echo "Deployment of 9 containers completed successfully."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
