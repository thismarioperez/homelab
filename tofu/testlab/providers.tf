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

provider "talos" {}
