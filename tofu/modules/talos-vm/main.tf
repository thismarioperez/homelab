# No cloud-init: Talos has no default user, no SSH, and takes no vendor-data
# snippet. It gets DHCP automatically at boot with no initialization block
# needed, and its machine config is applied post-boot via the talos provider
# (see tofu/testlab/talos.tf), not injected here. qemu-guest-agent comes from
# the Talos Image Factory schematic baked into the disk image (var.image_file_id)
# rather than a runcmd — the extension self-starts, no enable step needed.
resource "proxmox_virtual_environment_vm" "this" {
  name      = var.vm_name
  vm_id     = var.vm_id
  node_name = var.node_name
  tags      = var.tags

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory
  }

  # file_id (not import_from) because var.image_file_id is downloaded via
  # content_type = "iso" (Proxmox's content_type = "import" rejects
  # compressed raw disk images with a filename-extension validation error —
  # see the proxmox_download_file.talos comment in tofu/testlab/main.tf).
  # file_format must be set explicitly since content_type = "iso" doesn't
  # otherwise convey that the downloaded file is actually a raw disk image.
  disk {
    datastore_id = var.disk_datastore_id
    file_id      = var.image_file_id
    file_format  = "raw"
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }

  network_device {
    bridge      = var.network_bridge
    vlan_id     = var.vlan_id
    mac_address = var.mac_address
  }

  operating_system {
    type = "l26"
  }
}
