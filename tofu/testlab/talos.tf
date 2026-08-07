# Cluster-level Talos resources live here rather than in the talos-vm
# module: machine secrets, bootstrap, and kubeconfig are cluster-wide
# concerns, not per-VM ones.

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name         = "testlab"
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.talos_apiserver_vip]
  nodes                = local.k8s_vm_ips
}

data "talos_machine_configuration" "controller" {
  cluster_name       = "testlab"
  cluster_endpoint   = "https://${var.talos_apiserver_vip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  machine_type       = "controlplane"
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  # cluster_endpoint's inclusion as an apiserver cert SAN by default isn't
  # documented with certainty upstream — set it explicitly rather than rely
  # on unconfirmed default behavior, since clients (kubectl/talosctl)
  # connect via the VIP, not any node's own IP.
  config_patches = [
    yamlencode({
      machine = {
        certSANs = [var.talos_apiserver_vip]
      }
      cluster = {
        apiServer = {
          certSANs = [var.talos_apiserver_vip]
        }
      }
    }),
  ]
}

data "talos_machine_configuration" "worker" {
  cluster_name       = "testlab"
  cluster_endpoint   = "https://${var.talos_apiserver_vip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  machine_type       = "worker"
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
}

resource "talos_machine_configuration_apply" "controller" {
  count = length(var.k8s_controller_ips)

  # node/endpoint use the statically-assigned IP directly, so there's no
  # attribute reference tying this resource to
  # module.k8s_vm_controller — without this depends_on, tofu has no
  # ordering constraint and will race ahead trying to reach a VM that
  # doesn't exist yet, retrying until it times out.
  depends_on = [module.k8s_vm_controller]

  node     = var.k8s_controller_ips[count.index]
  endpoint = var.k8s_controller_ips[count.index]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controller.machine_configuration

  # Talos's native VIP mechanism replaces kube-vip's static pod — no extra
  # manifest needed, just this machine config field.
  #
  # deviceSelector (matched by MAC), not a hardcoded interface name: Talos
  # uses predictable interface names on Proxmox (enpXsY, assigned per PCI
  # slot) — "eth0" doesn't exist there (that fallback is cloud-platform-only,
  # where Talos injects net.ifnames=0) and silently attaches to nothing,
  # which was the actual cause of the VIP/DHCP config never applying and
  # the VM falling into Kea's dynamic pool instead of its MAC reservation.
  #
  # dhcp = false + explicit addresses/routes (not DHCP): Kea doesn't
  # release a MAC's lease just because its reservation is destroyed (see
  # the opnsense_kea_dhcpv4_reservation.k8s_vm comment in main.tf), so a
  # tofu destroy + re-apply cycle could hand the VM a stale leased address,
  # or drop it into the dynamic pool, instead of its intended static IP.
  # Configuring the address statically in Talos itself makes VM
  # provisioning independent of DHCP lease state entirely. The matching
  # Kea reservation is kept, but purely as a dynamic-pool exclusion guard
  # (same role it plays for the LB and VIP addresses) — not as the source
  # of truth for this address.
  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              deviceSelector = {
                hardwareAddr = local.k8s_vm_macs[count.index]
              }
              dhcp = false
              addresses = [
                "${var.k8s_controller_ips[count.index]}/${split("/", var.k8s_vm_subnet_cidr)[1]}"
              ]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.k8s_vm_subnet_gateway
                },
              ]
              vip = {
                ip = var.talos_apiserver_vip
              }
            },
          ]
          nameservers = [var.k8s_vm_subnet_gateway]
        }
      }
    }),
    # talos_machine_configuration's generated config always includes a
    # HostnameConfig{auto: stable} document (siderolabs/terraform-provider-talos#296).
    # Talos's config merge is not RFC 7396 (null doesn't delete a key), so
    # `auto` must be explicitly removed via Talos's own `$patch: delete`
    # syntax — otherwise `auto` survives the merge alongside `hostname` and
    # Talos rejects having both set ("'auto' and 'hostname' cannot be set
    # at the same time"). Do NOT use `auto: off` — regressed/rejected on
    # Talos >= 1.12.1 per the same upstream issue.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      hostname   = local.k8s_vm_names[count.index]
      auto = {
        "$patch" = "delete"
      }
    }),
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  count = length(var.k8s_worker_ips)

  # See the matching comment on talos_machine_configuration_apply.controller
  # — same reasoning, same fix.
  depends_on = [module.k8s_vm_worker]

  node     = var.k8s_worker_ips[count.index]
  endpoint = var.k8s_worker_ips[count.index]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration

  config_patches = [
    # Explicit interface config (matched by MAC, not a hardcoded name — see
    # the matching comment on talos_machine_configuration_apply.controller)
    # rather than relying on Talos's zero-config default DHCP path, so
    # behavior is identical and verifiable across both node roles.
    #
    # Static addressing (dhcp = false), not DHCP — see the matching
    # comment on talos_machine_configuration_apply.controller for why:
    # stale Kea leases survive a destroyed reservation and would otherwise
    # leave a recreated VM without its intended IP.
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              deviceSelector = {
                hardwareAddr = local.k8s_vm_macs[length(var.k8s_controller_ips) + count.index]
              }
              dhcp = false
              addresses = [
                "${var.k8s_worker_ips[count.index]}/${split("/", var.k8s_vm_subnet_cidr)[1]}"
              ]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.k8s_vm_subnet_gateway
                },
              ]
            },
          ]
          nameservers = [var.k8s_vm_subnet_gateway]
        }
      }
    }),
    # See the matching comment on talos_machine_configuration_apply.controller
    # — same HostnameConfig auto/hostname conflict, same $patch: delete fix.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      hostname   = local.k8s_vm_names[length(var.k8s_controller_ips) + count.index]
      auto = {
        "$patch" = "delete"
      }
    }),
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controller]

  node                 = var.k8s_controller_ips[0]
  endpoint             = var.k8s_controller_ips[0]
  client_configuration = talos_machine_secrets.this.client_configuration
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  node                 = var.k8s_controller_ips[0]
  endpoint             = var.talos_apiserver_vip
  client_configuration = talos_machine_secrets.this.client_configuration
}
