variable "node_name" {
  type        = string
  description = "Proxmox node to target"
  default     = "ryujin"
}

variable "vm_cores" {
  type        = number
  description = "Default vCPU cores for testbed VMs"
  default     = 1
}

variable "vm_threads" {
  type        = number
  description = "Default vCPU threads per core for testbed VMs"
  default     = 2
}

variable "vm_memory" {
  type        = number
  description = "Default memory (MB) for testbed VMs"
  default     = 2560
}

variable "vm_disk_size" {
  type        = string
  description = "Default disk size for testbed VMs"
  default     = "32G"
}

variable "vm_username" {
  type        = string
  description = "Default cloud-init user account username for testbed VMs (supply via TF_VAR_vm_username, e.g. through `op run`)"
}

variable "vm_password" {
  type        = string
  description = "Default cloud-init user account password for testbed VMs (supply via TF_VAR_vm_password, e.g. through `op run`)"
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key authorized on testbed VMs (supply via TF_VAR_ssh_public_key, e.g. through `op run`)"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID in USER@REALM!TOKENID format (supply via TF_VAR_proxmox_api_token_id, e.g. through `op run`)"
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "Proxmox API token secret (UUID) (supply via TF_VAR_proxmox_api_token_secret, e.g. through `op run`)"
  sensitive   = true
}

variable "proxmox_ssh_username" {
  type        = string
  description = "SSH username for the Proxmox node (supply via TF_VAR_proxmox_ssh_username, e.g. through `op run`)"
}

variable "proxmox_ssh_password" {
  type        = string
  description = "SSH password for the Proxmox node (supply via TF_VAR_proxmox_ssh_password, e.g. through `op run`)"
  sensitive   = true
}
