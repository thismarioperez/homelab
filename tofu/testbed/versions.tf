terraform {
  required_version = ">= 1.12"

  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    opnsense = {
      source  = "browningluke/opnsense"
      version = "~> 0.11"
    }
  }
}
