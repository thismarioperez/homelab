provider "onepassword" {}

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

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = var.proxmox_insecure
  api_token = "${local.proxmox_api_fields["token ID"].value}=${local.proxmox_api_fields["token secret"].value}"

  ssh {
    username = data.onepassword_item.secrets["proxmox_ssh"].username
    password = data.onepassword_item.secrets["proxmox_ssh"].password
  }
}

provider "opnsense" {
  uri            = var.opnsense_endpoint
  allow_insecure = var.opnsense_allow_insecure
  api_key        = local.opnsense_api_fields["api key"].value
  api_secret     = local.opnsense_api_fields["api secret"].value
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
  k3s_vm_names = [for i in range(var.k3s_vm_count) : "k3s-${i == 0 ? "controller" : "worker-${i}"}"]
  k3s_vm_ips   = [for i in range(var.k3s_vm_count) : cidrhost(var.k3s_vm_subnet_cidr, var.k3s_vm_ip_offset + i)]
  # Kea's "subnet" field is the interface IP (e.g. "10.30.60.1/24"), not the
  # network address, so it's normalized with cidrsubnet(..., 0, 0) before
  # comparing to var.k3s_vm_subnet_cidr.
  opnsense_kea_subnet_id = one([
    for row in jsondecode(data.http.opnsense_kea_subnets.response_body).rows :
    row.uuid if cidrsubnet(row.subnet, 0, 0) == var.k3s_vm_subnet_cidr
  ])
  # 02: locally administered, unicast (IEEE 802 bit convention) — avoids
  # colliding with real vendor OUIs so the MAC is safe to invent locally
  # and reuse for a stable OPNsense DHCP reservation.
  k3s_vm_macs = [
    for id in random_id.k3s_vm_mac :
    "02:${join(":", [for b in range(5) : substr(id.hex, b * 2, 2)])}"
  ]
}

resource "random_id" "k3s_vm_mac" {
  count = var.k3s_vm_count

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
  count = var.k3s_vm_count

  subnet_id   = local.opnsense_kea_subnet_id
  mac_address = local.k3s_vm_macs[count.index]
  ip_address  = local.k3s_vm_ips[count.index]
  hostname    = local.k3s_vm_names[count.index]
  description = "tofu: tofu/testbed k3s_vm module"
}

resource "proxmox_download_file" "ubuntu_2404" {
  content_type = "import"
  datastore_id = "local"
  node_name    = var.node_name
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.qcow2"
  overwrite    = false
}

module "k3s_vm" {
  count  = var.k3s_vm_count
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
