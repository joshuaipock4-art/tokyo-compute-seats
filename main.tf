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
  hostname         = "tokyo-bm"
  domain           = "tokyo-rentals.com"
  datacenter       = "tok02"
  os_reference_code = "UBUNTU_20_64"
  network_speed    = 1000
  hourly_billing   = true
  private_network_only = false

  # Hardware: 48 Cores (Dual Intel Xeon Gold 6248R), 128GB RAM
  package_key_name = "DUAL_INTEL_XEON_PROC_SCALABLE_GEN2_CASCADE_LAKE_12_DRIVES"
  process_key_name = "INTEL_INTEL_XEON_GOLD_6248R_3_00"
  memory           = 128

  # Storage: Dual 1TB SATA Drives
  disk_key_names   = ["HARD_DRIVE_1_00_TB_SATA_2", "HARD_DRIVE_1_00_TB_SATA_2"]

  # Use existing SSH Key
  ssh_key_ids      = [data.ibm_compute_ssh_key.termux_mobile.id]

  # User Data Script (IBM Classic uses user_metadata)
  user_metadata = file("${path.module}/scripts/setup.sh")
}
