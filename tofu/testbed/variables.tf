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
  description = "Map of logical secret name to 1Password item title: vm_login (VM cloud-init username/password), vm_ssh_key (VM cloud-init SSH key), proxmox_api (Proxmox API token id/secret), proxmox_ssh (Proxmox node SSH username/password), opnsense_api (OPNsense API key/secret)"
}

variable "opnsense_endpoint" {
  type        = string
  description = "OPNsense API base URL, no trailing slash (e.g. https://10.30.0.1) — the provider builds requests as \"<uri>/api/...\", and a trailing slash produces a double slash that OPNsense's ACL layer rejects with 403"
}

variable "opnsense_allow_insecure" {
  type        = bool
  description = "Skip TLS certificate verification for the OPNsense API endpoint"
  default     = false
}

variable "vlan_id" {
  type        = number
  description = "Default VLAN ID for testbed VMs"
  default     = 60
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

variable "opnsense_kea_subnet_id" {
  type        = string
  description = "OPNsense Kea DHCPv4 subnet UUID that var.vlan_id's subnet maps to (find via GET /api/kea/dhcpv4/search_subnet, or the docs/collections/OPNsense Bruno collection)"
}

variable "k3s_vm_subnet_cidr" {
  type        = string
  description = "CIDR of the subnet backing var.vlan_id, used to compute static reservation IPs for the k3s VMs"
  default     = "10.30.60.0/24"
}

variable "k3s_vm_ip_offset" {
  type        = number
  description = "Host offset (from the subnet's network address) of the first k3s VM's reserved IP; each subsequent VM gets the next offset. Must stay outside the subnet's DHCP dynamic pool"
  default     = 10
}
