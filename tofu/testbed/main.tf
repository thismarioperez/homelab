provider "proxmox" {
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"

  ssh {
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
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

module "test_vm" {
  source = "../modules/cloud-init-vm"

  vm_name       = "testbed-ubuntu-01"
  node_name     = var.node_name
  image_file_id = proxmox_download_file.ubuntu_2404.id

  cores     = var.vm_cores
  memory    = var.vm_memory
  disk_size = tonumber(trimsuffix(var.vm_disk_size, "G"))

  username = var.vm_username
  password = var.vm_password
  ssh_keys = [var.ssh_public_key]
}
