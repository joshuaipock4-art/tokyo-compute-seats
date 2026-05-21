terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.51.0"
    }
  }
}

provider "ibm" {
  region = "jp-tok"
}

# Data source to fetch the existing SSH key labeled 'termux-mobile'
data "ibm_compute_ssh_key" "termux_mobile" {
  label = "termux-mobile"
}

resource "ibm_compute_bare_metal" "tokyo_bare_metal" {
  hostname             = "tokyo-bm"
  domain               = "tokyo-rentals.com"
  datacenter           = "tok02"
  os_reference_code    = "UBUNTU_20_64"
  network_speed        = 1000
  hourly_billing       = true
  private_network_only = false

  # Hardware: 48 Cores (Dual Intel Xeon Gold 6248R), 128GB RAM
  package_key_name = "DUAL_INTEL_XEON_PROC_SCALABLE_GEN2_CASCADE_LAKE_12_DRIVES"
  process_key_name = "INTEL_INTEL_XEON_GOLD_6248R_3_00"
  memory           = 128

  # Storage: Dual 1TB SATA Drives
  disk_key_names = ["HARD_DRIVE_1_00_TB_SATA_2", "HARD_DRIVE_1_00_TB_SATA_2"]

  # Use existing SSH Key
  ssh_key_ids = [data.ibm_compute_ssh_key.termux_mobile.id]

  # User Data Script (IBM Classic uses user_metadata)
  user_metadata = <<-EOF
#!/bin/bash
set -e

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

# Deploy 9 isolated containers as per tier requirements
# 3x Ultra instances (8 cores / 12GB RAM)
for i in {1..3}; do launch_and_limit "ultra-$i" 8 12GB; done

# 3x Pro instances (4 cores / 8GB RAM)
for i in {1..3}; do launch_and_limit "pro-$i" 4 8GB; done

# 3x Starter instances (2 cores / 4GB RAM)
for i in {1..3}; do launch_and_limit "starter-$i" 2 4GB; done

echo "Deployment of 9 containers completed successfully."
EOF
}
