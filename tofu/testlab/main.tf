provider "onepassword" {}

provider "opnsense" {
  uri            = var.opnsense_endpoint
  allow_insecure = var.opnsense_allow_insecure
  api_key        = local.opnsense_api_fields["api key"].value
  api_secret     = local.opnsense_api_fields["api secret"].value
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = var.proxmox_insecure
  api_token = "${local.proxmox_api_fields["token ID"].value}=${local.proxmox_api_fields["token secret"].value}"

  ssh {
    username = data.onepassword_item.secrets["proxmox_ssh"].username
    password = data.onepassword_item.secrets["proxmox_ssh"].password
  }
}

provider "ansible" {}

data "onepassword_vault" "this" {
  name = var.op_vault_name
}

data "onepassword_item" "secrets" {
  for_each = var.op_items

  vault = data.onepassword_vault.this.uuid
  title = each.value
}

locals {
  # "Proxmox Test Server - tofu" stores the token as custom fields ("token
  # ID"/"token secret") rather than the native username/password attributes,
  # so they're read via section_map/field_map. Verify the section label with
  # `tofu console` or `op item get` if this doesn't resolve.
  proxmox_api_fields  = data.onepassword_item.secrets["proxmox_api"].section_map[""].field_map
  opnsense_api_fields = data.onepassword_item.secrets["opnsense_api"].section_map[""].field_map
}

# The opnsense provider only exposes a get-by-UUID data source for Kea
# subnets, so the search endpoint is called directly here to resolve
# var.k3s_vm_subnet_cidr to its subnet UUID without a manual lookup.
data "http" "opnsense_kea_subnets" {
  url = "${var.opnsense_endpoint}/api/kea/dhcpv4/search_subnet"

  request_headers = {
    Authorization = "Basic ${base64encode("${local.opnsense_api_fields["api key"].value}:${local.opnsense_api_fields["api secret"].value}")}"
  }

  insecure = var.opnsense_allow_insecure
}

locals {
  k3s_vm_ips = concat(var.k3s_controller_ips, var.k3s_worker_ips)
  k3s_vm_names = concat(
    [for i in range(length(var.k3s_controller_ips)) : "k3s-controller-${i + 1}"],
    [for i in range(length(var.k3s_worker_ips)) : "k3s-worker-${i + 1}"],
  )
  k3s_vm_count = length(local.k3s_vm_ips)
  # Kea's "subnet" field is the interface IP (e.g. "10.30.60.1/24"), not the
  # network address, so it's normalized with cidrsubnet(..., 0, 0) before
  # comparing to var.k3s_vm_subnet_cidr.
  opnsense_kea_subnet_id = one([
    for row in jsondecode(data.http.opnsense_kea_subnets.response_body).rows :
    row.uuid if cidrsubnet(row.subnet, 0, 0) == var.k3s_vm_subnet_cidr
  ])
  # 02: locally administered, unicast (IEEE 802 bit convention) — avoids
  # colliding with real vendor OUIs so the MAC is safe to invent locally
  # and reuse for a stable OPNsense DHCP reservation. Centralized here so
  # every random_id.*.hex → MAC conversion (per-VM, LB, apiserver VIP) shares
  # one formatting expression instead of repeating it per resource.
  mac_from_hex          = { for name, hex in local.mac_source_hex : name => "02:${join(":", [for b in range(5) : substr(hex, b * 2, 2)])}" }
  k3s_vm_macs           = [for i in range(local.k3s_vm_count) : local.mac_from_hex["vm-${i}"]]
  k3s_lb_mac            = local.mac_from_hex["lb"]
  k3s_apiserver_vip_mac = local.mac_from_hex["apiserver_vip"]

  mac_source_hex = merge(
    { for i, id in random_id.k3s_vm_mac : "vm-${i}" => id.hex },
    {
      lb            = random_id.k3s_lb_mac.hex
      apiserver_vip = random_id.k3s_apiserver_vip_mac.hex
    },
  )
}

resource "random_id" "k3s_vm_mac" {
  count = local.k3s_vm_count

  byte_length = 5

  keepers = {
    vm_name = local.k3s_vm_names[count.index]
  }
}

# Created from random_id alone (not the VM's own reported MAC) so it has no
# dependency on module.k3s_vm — the reservation must exist in OPNsense
# *before* the VM's first boot requests a DHCP lease, otherwise the VM picks
# up a dynamic-pool address instead of the reserved one.
resource "opnsense_kea_dhcpv4_reservation" "k3s_vm" {
  count = local.k3s_vm_count

  subnet_id   = local.opnsense_kea_subnet_id
  mac_address = local.k3s_vm_macs[count.index]
  ip_address  = local.k3s_vm_ips[count.index]
  hostname    = local.k3s_vm_names[count.index]
  description = "tofu: tofu/testlab k3s_vm module"
}

# Kea has no IPv4 pool-exclusion primitive, but a host reservation is
# excluded from the dynamic pool regardless of whether any device ever
# claims it — so a reservation to a synthetic, never-requesting MAC
# reserves var.k3s_lb_ip for MetalLB without any real device attached.
resource "random_id" "k3s_lb_mac" {
  byte_length = 5

  keepers = {
    purpose = "k3s_lb"
  }
}

resource "opnsense_kea_dhcpv4_reservation" "k3s_lb" {
  subnet_id   = local.opnsense_kea_subnet_id
  mac_address = local.k3s_lb_mac
  ip_address  = var.k3s_lb_ip
  hostname    = "k8s-lb"
  description = "tofu: tofu/testlab MetalLB LoadBalancer IP exclusion — not a real device"
}

# Same synthetic-MAC exclusion pattern as k3s_lb, reserving
# var.k3s_apiserver_vip for kube-vip to announce as the k3s control plane's
# floating apiserver address.
resource "random_id" "k3s_apiserver_vip_mac" {
  byte_length = 5

  keepers = {
    purpose = "k3s_apiserver_vip"
  }
}

resource "opnsense_kea_dhcpv4_reservation" "k3s_apiserver_vip" {
  subnet_id   = local.opnsense_kea_subnet_id
  mac_address = local.k3s_apiserver_vip_mac
  ip_address  = var.k3s_apiserver_vip
  hostname    = "k8s-apiserver-vip"
  description = "tofu: tofu/testlab kube-vip k3s apiserver VIP exclusion — not a real device"
}

resource "time_rotating" "ubuntu_2404_refresh" {
  rotation_days = 180
}

resource "proxmox_download_file" "ubuntu_2404" {
  content_type = "import"
  datastore_id = "local"
  node_name    = var.node_name
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.qcow2"
  overwrite    = false

  lifecycle {
    replace_triggered_by = [time_rotating.ubuntu_2404_refresh.id]
  }
}

module "k3s_vm" {
  count  = local.k3s_vm_count
  source = "../modules/ubuntu-vm"

  # Explicit: the mac_address/ip_config inputs below don't reference the
  # reservation, so without this the two resources have no ordering
  # constraint and could apply in parallel.
  depends_on = [opnsense_kea_dhcpv4_reservation.k3s_vm]

  vm_name       = local.k3s_vm_names[count.index]
  node_name     = var.node_name
  image_file_id = proxmox_download_file.ubuntu_2404.id

  cores       = var.vm_cores
  memory      = var.vm_memory
  disk_size   = tonumber(trimsuffix(var.vm_disk_size, "G"))
  vlan_id     = var.vlan_id
  mac_address = local.k3s_vm_macs[count.index]

  username = data.onepassword_item.secrets["vm_login"].username
  password = data.onepassword_item.secrets["vm_login"].password
  ssh_keys = [data.onepassword_item.secrets["vm_ssh_key"].public_key]
}

resource "ansible_host" "k3s_vm" {
  count = local.k3s_vm_count

  # depends on the actual VM, not just the reservation, so inventory only
  # lists hosts that have actually been provisioned
  depends_on = [module.k3s_vm]

  name   = local.k3s_vm_names[count.index]
  groups = [count.index < length(var.k3s_controller_ips) ? "k3s_controllers" : "k3s_workers"]
  variables = {
    ansible_host = local.k3s_vm_ips[count.index]
  }
}
