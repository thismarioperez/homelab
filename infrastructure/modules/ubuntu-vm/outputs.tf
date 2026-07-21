output "vm_id" {
  description = "Proxmox VM ID of the created VM"
  value       = proxmox_virtual_environment_vm.this.vm_id
}
