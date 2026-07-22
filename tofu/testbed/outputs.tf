output "vm_network_info" {
  description = "MAC and IPv4 addresses of deployed VMs, keyed by VM name (ip_address is null until the QEMU guest agent reports in)"
  value = {
    for vm in module.k3s_vm : vm.vm_name => {
      mac_address = vm.mac_address
      ip_address  = vm.ip_address
    }
  }
}
