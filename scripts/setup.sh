#!/bin/bash
set -e

# PATH setup to ensure snap binaries (/snap/bin) are accessible
export PATH=$PATH:/snap/bin

# Function to safely locate a secondary, non-root disk for storage
get_target_disk() {
  # Find the disk device holding the root filesystem (/)
  local root_dev
  root_dev=$(findmnt -n -o SOURCE / 2>/dev/null || true)
  local root_disk=""
  if [[ -n "$root_dev" ]]; then
    root_disk=$(lsblk -no PKNAME "$root_dev" 2>/dev/null || true)
    if [[ -z "$root_disk" ]]; then
      # If root_dev was a full disk or PKNAME returned empty, extract base disk name
      root_disk=$(echo "$root_dev" | sed -E "s/p?[0-9]+$//; s|^/dev/||")
    fi
  fi

  # Find disk devices of type "disk" that are not the root disk
  local target_disk=""
  for disk in $(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk" {print $1}'); do
    if [[ "$disk" != "$root_disk" ]]; then
      target_disk="/dev/$disk"
      break
    fi
  done

  if [[ -z "$target_disk" ]]; then
    echo "Error: Could not identify an available secondary disk for ZFS storage pool." >&2
    return 1
  fi

  echo "$target_disk"
}

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

  # Dynamically discover an available secondary disk (avoiding the OS root disk)
  local target_disk
  target_disk=$(get_target_disk)
  if [[ -z "$target_disk" ]]; then
    echo "Aborting setup: No suitable secondary disk found." >&2
    return 1
  fi

  echo "Target disk identified for ZFS storage: $target_disk"

  # Prepare the target disk for ZFS
  wipefs -a "$target_disk"
  zpool create -f lxd-pool "$target_disk"

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
