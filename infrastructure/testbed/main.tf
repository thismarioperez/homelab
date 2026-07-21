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
  proxmox_api_fields = data.onepassword_item.secrets["proxmox_api"].section_map[""].field_map
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

  vm_name       = "k3s-${count.index == 0 ? "server" : "agent-${count.index}"}"
  node_name     = var.node_name
  image_file_id = proxmox_download_file.ubuntu_2404.id

  cores     = var.vm_cores
  memory    = var.vm_memory
  disk_size = tonumber(trimsuffix(var.vm_disk_size, "G"))
  vlan_id   = var.vlan_id

  username = data.onepassword_item.secrets["vm_login"].username
  password = data.onepassword_item.secrets["vm_login"].password
  ssh_keys = [data.onepassword_item.secrets["vm_ssh_key"].public_key]
}
