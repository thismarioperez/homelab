output "vm_id" {
  description = "Proxmox VM ID of the created VM"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "vm_name" {
  description = "Name of the created VM"
  value       = proxmox_virtual_environment_vm.this.name
}

output "mac_address" {
  description = "MAC address of the VM's network interface"
  value       = proxmox_virtual_environment_vm.this.network_device[0].mac_address
}
