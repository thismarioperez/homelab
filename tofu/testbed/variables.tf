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
