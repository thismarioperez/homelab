variable "vm_name" {
  type        = string
  description = "Name of the VM"
}

variable "vm_id" {
  type        = number
  description = "Proxmox VM ID (auto-assigned if null)"
  default     = null
}

variable "node_name" {
  type        = string
  description = "Proxmox node to create the VM on"
}

variable "image_file_id" {
  type        = string
  description = "ID of an already-downloaded proxmox_virtual_environment_download_file resource (a Talos Image Factory disk image, downloaded via content_type = \"iso\" per the proxmox_download_file.talos comment in tofu/testlab/main.tf) to use as the VM disk's file_id"
}

variable "disk_datastore_id" {
  type        = string
  description = "Datastore for the VM disk"
  default     = "storage"
}

variable "disk_size" {
  type        = number
  description = "VM disk size in GB"
  default     = 32
}

variable "cores" {
  type        = number
  description = "Number of vCPU cores"
  default     = 1
}

variable "cpu_type" {
  type        = string
  description = "QEMU CPU type exposed to the VM. Proxmox defaults to \"qemu64\" (a maximally conservative baseline lacking sse4_1/sse4_2/ssse3/popcnt) if unset, which breaks binaries compiled for the x86-64-v2 baseline or newer."
  default     = "host"
}

variable "memory" {
  type        = number
  description = "Dedicated memory in MB"
  default     = 2048
}

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge to attach the VM to"
  default     = "vmbr0"
}

variable "vlan_id" {
  type        = number
  description = "VLAN tag to apply to the VM's network interface (null for no tagging)"
  default     = null
}

variable "mac_address" {
  type        = string
  description = "MAC address to assign to the VM's network interface (null to let Proxmox auto-generate one)"
  default     = null
}

variable "tags" {
  type        = list(string)
  description = "Tags to apply to the VM"
  default     = []
}
