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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
}
