variable "node_name" {
  type        = string
  description = "Proxmox node to target"
  default     = "pve"
}

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox VE API endpoint URL (e.g. https://10.30.0.23:8006/)"
}

variable "proxmox_insecure" {
  type        = bool
  description = "Skip TLS certificate verification for the Proxmox API endpoint"
  default     = false
}

variable "op_vault_name" {
  type        = string
  description = "1Password vault name containing testbed secrets"
}

variable "op_items" {
  type        = map(string)
  description = "Map of logical secret name to 1Password item title: vm_login (VM cloud-init username/password), vm_ssh_key (VM cloud-init SSH key), proxmox_api (Proxmox API token id/secret), proxmox_ssh (Proxmox node SSH username/password)"
}

variable "vlan_id" {
  type        = number
  description = "Default VLAN ID for testbed VMs"
  default     = 10
}

variable "vm_cores" {
  type        = number
  description = "Default vCPU cores for testbed VMs"
  default     = 2
}

variable "vm_disk_size" {
  type        = string
  description = "Default disk size for testbed VMs"
  default     = "32G"
}

variable "vm_memory" {
  type        = number
  description = "Default memory (MB) for testbed VMs"
  default     = 2560
}

variable "k3s_vm_count" {
  type        = number
  description = "Number of k3 nodes"
  default     = 3
}
