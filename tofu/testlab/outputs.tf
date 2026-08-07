output "talos_apiserver_vip" {
  description = "IP address reserved for Talos's native VIP mechanism to announce as the control plane's floating apiserver address"
  value       = var.talos_apiserver_vip
}

output "k8s_lb_ip" {
  description = "IP address reserved for MetalLB to announce as the cluster's LoadBalancer address"
  value       = var.k8s_lb_ip
}

output "talos_kubeconfig" {
  description = "Raw kubeconfig for the testlab Talos cluster"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talos_config" {
  description = "Raw talosconfig (talosctl client config) for the testlab Talos cluster"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "vm_network_info" {
  description = "MAC and IPv4 addresses of deployed VMs, keyed by VM name. ip_address is the VM's statically-configured address (known before apply, not reported by the guest agent) — the matching Kea reservation only excludes it from the DHCP dynamic pool"
  value = {
    for i, vm in local.k8s_vms : vm.vm_name => {
      mac_address = vm.mac_address
      ip_address  = local.k8s_vm_ips[i]
    }
  }
}
