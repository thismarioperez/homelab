# Homelab

🚧 Work in progress.

Infrastructure-as-code for my homelab: Proxmox VMs and OPNsense networking
provisioned with OpenTofu, configured with Ansible.

## Docs

- [Workstation setup](docs/workstation-setup.md)
- [Backblaze B2 Tofu state backend](docs/backblaze-b2-tofu-state.md)
- [OPNsense Bruno collection](docs/collections/OPNsense/README.md) — for
  exploring the OPNsense router's REST API

## Goals

- [x] Finish testlab k3s cluster
- [x] Setup HA testlab k3s cluster
- [ ] Improve `testlab` tofu project structure
- [ ] Expand Ansible playbooks
- [ ] Take inventory of existing snowflake nodes in Lab
- [ ] Create K3s cluster in Lab
- [ ] Migrate snowflake services to cluster
- [ ] De-provision old snowflake nodes
