variable "node_name" {
  type        = string
  description = "Proxmox node to target"
  default     = "ryujin"
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
  description = "1Password vault name containing testlab secrets"
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
  description = "Default VLAN ID for testlab VMs"
  default     = 60
}

variable "vm_cores" {
  type        = number
  description = "Default vCPU cores for testlab VMs"
  default     = 2
}

variable "k3s_controller_disk_size" {
  type        = string
  description = "Disk size for k3s controller VMs"
  default     = "80G"
}

variable "k3s_worker_disk_size" {
  type        = string
  description = "Disk size for k3s worker VMs"
  default     = "620G"
}

variable "k3s_controller_memory" {
  type        = number
  description = "Memory (MB) for k3s controller VMs"
  default     = 6144
}

variable "k3s_worker_memory" {
  type        = number
  description = "Memory (MB) for k3s worker VMs"
  default     = 18432
}

variable "k3s_vm_subnet_cidr" {
  type        = string
  description = "CIDR of the subnet backing var.vlan_id, used to resolve the OPNsense Kea subnet for k3s VM/VIP DHCP reservations"
  default     = "10.30.60.0/24"
}

variable "k3s_apiserver_vip" {
  type        = string
  description = "IP address reserved (excluded from the DHCP dynamic pool) for kube-vip to announce as the k3s control plane's floating apiserver address. Must stay outside the subnet's DHCP dynamic pool and not collide with other static reservations"
  default     = "10.30.60.10"
}

variable "k3s_lb_ip" {
  type        = string
  description = "IP address reserved (excluded from the DHCP dynamic pool) for MetalLB to announce as the cluster's single LoadBalancer address. Must stay outside the subnet's DHCP dynamic pool and not collide with other static reservations"
  default     = "10.30.60.11"
}

variable "k3s_controller_ips" {
  type        = list(string)
  description = "Static IPs to reserve for k3s controller (server) nodes, one per node; list length determines the controller count"
  default     = ["10.30.60.12"]
}

variable "k3s_worker_ips" {
  type        = list(string)
  description = "Static IPs to reserve for k3s worker (agent) nodes, one per node; list length determines the worker count"
  default     = ["10.30.60.13"]
}
