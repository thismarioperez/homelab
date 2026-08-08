# Homelab

🚧 Work in progress.

Infrastructure-as-code for my homelab: Proxmox VMs and OPNsense networking
provisioned with OpenTofu, configured with Ansible.

## Docs

- [Workstation setup](docs/workstation-setup.md)
- [Backblaze B2 Tofu state backend](docs/backblaze-b2-tofu-state.md)
- [OPNsense Bruno collection](docs/collections/OPNsense/README.md) — for
  exploring the OPNsense router's REST API
- [Hardware](docs/hardware.md) — physical devices in the lab
- [Kubernetes](docs/kubernetes.md) — cluster standup steps and resource
  distribution across cluster VMs

## TODO

- [x] Finish testlab k8s cluster
- [x] Setup HA testlab k8s cluster
- [x] Improve `testlab` tofu project structure
- [x] Setup persistent storage and backup solution for k8s clusters with [volsync](https://volsync.readthedocs.io/en/stable/)
- [x] Setup Flux for in-cluster GitOps reconciliation (replace local `kustomize --enable-helm` applies)
- [ ] Take inventory of existing snowflake nodes in Lab
- [ ] Create k8s cluster in Lab
- [ ] Migrate snowflake services to cluster
- [ ] De-provision old snowflake nodes
