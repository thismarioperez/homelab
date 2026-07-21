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
  description = "ID of an already-downloaded proxmox_virtual_environment_download_file resource to import the disk from"
}

variable "disk_datastore_id" {
  type        = string
  description = "Datastore for the VM disk and cloud-init drive"
  default     = "storage"
}

variable "snippets_datastore_id" {
  type        = string
  description = "Datastore to upload the cloud-init vendor-data snippet to (must support the 'snippets' content type)"
  default     = "local"
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

variable "username" {
  type        = string
  description = "Default cloud-init user account username"
}

variable "password" {
  type        = string
  description = "Default cloud-init user account password"
  default     = null
  sensitive   = true
}

variable "ssh_keys" {
  type        = list(string)
  description = "SSH public keys to authorize for the default user"
  default     = []
}

variable "tags" {
  type        = list(string)
  description = "Tags to apply to the VM"
  default     = []
}
