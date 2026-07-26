output "vm_network_info" {
  description = "MAC and IPv4 addresses of deployed VMs, keyed by VM name (ip_address is the address actually reported by the QEMU guest agent, null until it reports in; reserved_ip_address is the OPNsense DHCP reservation's intended address and should match once DHCP has run)"
  value = {
    for i, vm in module.k3s_vm : vm.vm_name => {
      mac_address         = vm.mac_address
      ip_address          = vm.ip_address
      reserved_ip_address = local.k3s_vm_ips[i]
    }
  }
}
