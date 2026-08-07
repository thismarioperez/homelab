# The opnsense provider only exposes a get-by-UUID data source for Kea
# subnets, so the search endpoint is called directly here to resolve
# var.k8s_vm_subnet_cidr to its subnet UUID without a manual lookup.
data "http" "opnsense_kea_subnets" {
  url = "${var.opnsense_endpoint}/api/kea/dhcpv4/search_subnet"

  request_headers = {
    Authorization = "Basic ${base64encode("${local.opnsense_api_fields["api key"].value}:${local.opnsense_api_fields["api secret"].value}")}"
  }

  insecure = var.opnsense_allow_insecure
}

locals {
  k8s_vm_ips = concat(var.k8s_controller_ips, var.k8s_worker_ips)
  k8s_vm_names = concat(
    [for i in range(length(var.k8s_controller_ips)) : "k8s-controller-${i + 1}"],
    [for i in range(length(var.k8s_worker_ips)) : "k8s-worker-${i + 1}"],
  )
  k8s_vm_count = length(local.k8s_vm_ips)
  # Kea's "subnet" field is the interface IP (e.g. "10.30.60.1/24"), not the
  # network address, so it's normalized with cidrsubnet(..., 0, 0) before
  # comparing to var.k8s_vm_subnet_cidr.
  opnsense_kea_subnet_id = one([
    for row in jsondecode(data.http.opnsense_kea_subnets.response_body).rows :
    row.uuid if cidrsubnet(row.subnet, 0, 0) == var.k8s_vm_subnet_cidr
  ])
  # 02: locally administered, unicast (IEEE 802 bit convention) — avoids
  # colliding with real vendor OUIs so the MAC is safe to invent locally
  # and reuse for a stable OPNsense DHCP reservation. Centralized here so
  # every random_id.*.hex → MAC conversion (per-VM, LB, apiserver VIP) shares
  # one formatting expression instead of repeating it per resource.
  mac_from_hex          = { for name, hex in local.mac_source_hex : name => "02:${join(":", [for b in range(5) : substr(hex, b * 2, 2)])}" }
  k8s_vm_macs           = [for i in range(local.k8s_vm_count) : local.mac_from_hex["vm-${i}"]]
  k8s_lb_mac            = local.mac_from_hex["lb"]
  k8s_apiserver_vip_mac = local.mac_from_hex["apiserver_vip"]

  mac_source_hex = merge(
    { for i, id in random_id.k8s_vm_mac : "vm-${i}" => id.hex },
    {
      lb            = random_id.k8s_lb_mac.hex
      apiserver_vip = random_id.k8s_apiserver_vip_mac.hex
    },
  )
}

resource "random_id" "k8s_vm_mac" {
  count = local.k8s_vm_count

  byte_length = 5

  keepers = {
    vm_name = local.k8s_vm_names[count.index]
  }
}

# Created from random_id alone (not the VM's own reported MAC) so it has no
# dependency on module.k8s_vm on apply — the reservation must exist in
# OPNsense *before* the VM's first boot requests a DHCP lease, otherwise the
# VM picks up a dynamic-pool address instead of the reserved one.
resource "opnsense_kea_dhcpv4_reservation" "k8s_vm" {
  count = local.k8s_vm_count

  subnet_id   = local.opnsense_kea_subnet_id
  mac_address = local.k8s_vm_macs[count.index]
  ip_address  = local.k8s_vm_ips[count.index]
  hostname    = local.k8s_vm_names[count.index]
  description = "tofu: tofu/testlab k8s_vm module — pool exclusion only, VM uses a static IP configured in Talos, not DHCP"
}

# Kea doesn't release a MAC's DHCP lease just because its reservation is
# destroyed — a stale lease for the same MAC/IP can survive a tofu destroy
# and get reissued to that MAC on next boot, causing the VM to keep the old
# leased address instead of the (recreated) reservation's IP until the lease
# naturally expires or is manually cleared in the OPNsense UI (observed
# firsthand rebuilding this cluster). A tofu-destroy-time API call to
# OPNsense's lease-delete endpoint (/api/kea/leases4/del_lease/, wraps Kea's
# native lease4-del — https://github.com/opnsense/core/pull/10019) was
# attempted here via a terraform_data + local-exec curl provisioner, but
# that endpoint enforces CSRF protection even against API-key Basic-auth
# POST requests (confirmed by hand: correct auth, correct body, -L to
# follow the http->https redirect, still a hard 403 "CSRF check failed" —
# not a curl or encoding issue). No workaround was found short of scripting
# a full GUI session login (cookie + CSRF token) to reach this endpoint, so
# it was abandoned rather than shipped broken. Until that changes, a stale
# lease must be cleared manually in the OPNsense UI after destroy if it
# blocks a subsequent apply from getting its reserved IP immediately.

# Kea has no IPv4 pool-exclusion primitive, but a host reservation is
# excluded from the dynamic pool regardless of whether any device ever
# claims it — so a reservation to a synthetic, never-requesting MAC
# reserves var.k8s_lb_ip for MetalLB without any real device attached.
resource "random_id" "k8s_lb_mac" {
  byte_length = 5

  keepers = {
    purpose = "k8s_lb"
  }
}

resource "opnsense_kea_dhcpv4_reservation" "k8s_lb" {
  subnet_id   = local.opnsense_kea_subnet_id
  mac_address = local.k8s_lb_mac
  ip_address  = var.k8s_lb_ip
  hostname    = "k8s-lb"
  description = "tofu: tofu/testlab MetalLB LoadBalancer IP exclusion — not a real device"
}

# Same synthetic-MAC exclusion pattern as k8s_lb, reserving
# var.talos_apiserver_vip for Talos's native VIP mechanism to announce as
# the control plane's floating apiserver address.
resource "random_id" "k8s_apiserver_vip_mac" {
  byte_length = 5

  keepers = {
    purpose = "k8s_apiserver_vip"
  }
}

resource "opnsense_kea_dhcpv4_reservation" "talos_apiserver_vip" {
  subnet_id   = local.opnsense_kea_subnet_id
  mac_address = local.k8s_apiserver_vip_mac
  ip_address  = var.talos_apiserver_vip
  hostname    = "k8s-apiserver-vip"
  description = "tofu: tofu/testlab Talos apiserver VIP exclusion — not a real device"
}

# Requests a Talos Image Factory schematic with the qemu-guest-agent system
# extension baked in — this is what lets Proxmox report VM status and IP in
# the UI. The talos provider resources below don't depend on it: they key off
# the statically-assigned IPs directly rather than waiting on the guest agent.
#
# iscsi-tools + util-linux-tools are required by Longhorn (iscsid/iscsiadm
# and kernel module tooling aren't in the Talos base image) — see
# https://longhorn.io/docs/1.12.0/advanced-resources/os-distro-specific/talos-linux-support/
resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/qemu-guest-agent",
          "siderolabs/iscsi-tools",
          "siderolabs/util-linux-tools",
        ]
      }
    }
  })
}

# content_type = "import" has strict server-side filename-extension
# validation (only .ova/.ovf/.qcow2/.raw/.vmdk, and is unreliable pre-PVE
# 8.4) that doesn't understand compression suffixes — it rejects this
# download with "invalid filename or wrong extension" regardless of what
# the file_name says. content_type = "iso" + a bare .img file_name is the
# provider-maintainer-confirmed workaround for compressed (zst/xz) raw
# disk images: decompression happens server-side via
# decompression_algorithm, and the VM disk block references the result via
# file_id + file_format = "raw" instead of import_from.
# https://github.com/bpg/terraform-provider-proxmox/issues/2436
# https://github.com/bpg/terraform-provider-proxmox/issues/2208
resource "proxmox_download_file" "talos" {
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = var.node_name
  url                     = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.raw.zst"
  file_name               = "talos-${var.talos_version}-${substr(talos_image_factory_schematic.this.id, 0, 8)}.img"
  decompression_algorithm = "zst"
  overwrite               = false
}

module "k8s_vm_controller" {
  count  = length(var.k8s_controller_ips)
  source = "../modules/talos-vm"

  # Explicit: the mac_address inputs below don't reference the reservation,
  # so without this the two resources have no ordering constraint and could
  # apply in parallel.
  depends_on = [opnsense_kea_dhcpv4_reservation.k8s_vm]

  vm_name       = local.k8s_vm_names[count.index]
  node_name     = var.node_name
  image_file_id = proxmox_download_file.talos.id

  cores       = var.vm_cores
  memory      = var.k8s_controller_memory
  disk_size   = tonumber(trimsuffix(var.k8s_controller_disk_size, "G"))
  vlan_id     = var.vlan_id
  mac_address = local.k8s_vm_macs[count.index]
}

module "k8s_vm_worker" {
  count  = length(var.k8s_worker_ips)
  source = "../modules/talos-vm"

  # Explicit: the mac_address inputs below don't reference the reservation,
  # so without this the two resources have no ordering constraint and could
  # apply in parallel.
  depends_on = [opnsense_kea_dhcpv4_reservation.k8s_vm]

  vm_name       = local.k8s_vm_names[length(var.k8s_controller_ips) + count.index]
  node_name     = var.node_name
  image_file_id = proxmox_download_file.talos.id

  cores       = var.vm_cores
  memory      = var.k8s_worker_memory
  disk_size   = tonumber(trimsuffix(var.k8s_worker_disk_size, "G"))
  vlan_id     = var.vlan_id
  mac_address = local.k8s_vm_macs[length(var.k8s_controller_ips) + count.index]
}

locals {
  # Controllers first, then workers — matches local.k8s_vm_names/k8s_vm_ips
  # ordering, so index i here lines up with local.k8s_vm_ips[i].
  k8s_vms = concat(module.k8s_vm_controller, module.k8s_vm_worker)
}
