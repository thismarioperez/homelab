resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name

  source_raw {
    file_name = "${var.vm_name}-user-data.yaml"
    data      = <<-EOF
      #cloud-config
      hostname: ${var.vm_name}
      users:
        - default
        - name: ${var.username}
          groups:
            - sudo
          shell: /bin/bash
          sudo: ALL=(ALL) NOPASSWD:ALL
          lock_passwd: false
          ssh_authorized_keys:
      %{~for key in var.ssh_keys~}
            - ${key}
      %{~endfor~}
      %{~if var.password != null~}
          passwd: ${bcrypt(var.password)}
      %{~endif~}
      package_update: true
      packages:
        - qemu-guest-agent
      runcmd:
        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent
    EOF
  }
}

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
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.disk_datastore_id
    import_from  = var.image_file_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }

  initialization {
    datastore_id = var.disk_datastore_id

    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge = var.network_bridge
  }

  operating_system {
    type = "l26"
  }
}
