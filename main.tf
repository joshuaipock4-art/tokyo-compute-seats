# 1. Define the IBM Provider
terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.60"
    }
  }
}

provider "ibm" {
  region = "jp-tok"
}

# 2. Install Your Master SSH Keys (The Padlocks)
resource "ibm_compute_ssh_key" "chromebook_key" {
  label      = "chromebook-master"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFJ/Bx8TuroZ+uDiqUzn6qi3KTlKv4vTqLHtbHnYtZil ibm-tokyo-server"
}

resource "ibm_compute_ssh_key" "termux_key" {
  label      = "termux-mobile"
  public_key = "ssh-ed25519 AAAAC3NzaC11ZDI1NTE5AAAAIP/pkK3kcLFZeVt6XbzrwGhOAGybceI0K1a9yYxJDEFS termux-mobile"
}

# 3. Order the Bare Metal Server in Tokyo
resource "ibm_compute_bare_metal" "tokyo_compute_seats" {
  hostname             = "tokyo-seats"
  domain               = "truecare.local"
  os_reference_code    = "UBUNTU_22_64"
  datacenter           = "tok02" # IBM's Tokyo Datacenter
  network_speed        = 1000    # 1 Gbps connection for low latency
  hourly_billing       = true    # Changed to hourly billing
  private_network_only = false
  
  # Standard baseline hardware preset for bare-metal
  fixed_config_preset  = "S1270_8GB_2X1TBSATA_NORAID" 

  # Attach your SSH padlocks to the server's root administrator account
  ssh_key_ids = [
    ibm_compute_ssh_key.chromebook_key.id,
    ibm_compute_ssh_key.termux_key.id
  ]
}
