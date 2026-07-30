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
