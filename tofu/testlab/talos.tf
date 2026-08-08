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

  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              deviceSelector = {
                hardwareAddr = local.k8s_vm_macs[count.index]
              }
              dhcp = true
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
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              deviceSelector = {
                hardwareAddr = local.k8s_vm_macs[length(var.k8s_controller_ips) + count.index]
              }
              dhcp = true
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
    # Talos's root filesystem is ephemeral/read-only by design, so kubelet
    # (and containers it starts, e.g. Longhorn's manager/engine pods) can't
    # see host paths outside what's explicitly bind-mounted in. Longhorn's
    # defaultDataPath (kubernetes/testlab/apps/storage-system/longhorn)
    # needs this or every volume fails to schedule a replica with "No
    # available disk candidates" — the manager reports the disk but the
    # underlying path was never actually accessible to it.
    # https://longhorn.io/docs/1.9.1/advanced-resources/os-distro-specific/talos-linux-support/
    yamlencode({
      machine = {
        kubelet = {
          extraMounts = [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/var/lib/longhorn"
              options     = ["bind", "rshared", "rw"]
            },
          ]
        }
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
