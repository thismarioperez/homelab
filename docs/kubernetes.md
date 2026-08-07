# Kubernetes

Cluster standup steps and resource distribution for the Kubernetes clusters
in this repo.

## Standing up a fresh cluster

End-to-end steps to bring up the `testlab` Talos cluster from nothing:
Proxmox VMs, Talos, and the full app stack. Assumes
[workstation setup](workstation-setup.md) is already done (tools installed,
1Password auth configured, tofu state backend reachable).

### 1. Provision the VMs and bootstrap the cluster (OpenTofu)

```bash
mise run tofu:testlab:init
mise run tofu:testlab:plan
mise run tofu:testlab:apply
```

Creates the controller and worker VMs on Proxmox, applies Talos machine
config, bootstraps etcd, and produces a kubeconfig/talosconfig — all in one
`tofu apply` — per `tofu/testlab/` (see [resource distribution](#testlab)
below for sizing). No separate OS-install/Ansible step is needed: Talos has
no SSH or cloud-init, so the `siderolabs/talos` provider resources in
`tofu/testlab/talos.tf` handle everything node-level directly.

### 2. Fetch the kubeconfig

```bash
mise run talos:testlab:kubeconfig
```

Writes `tofu/testlab/.cache/kubeconfig.yaml`, pointed at Talos's native VIP
for the control plane's floating apiserver address.

```bash
export KUBECONFIG=tofu/testlab/.cache/kubeconfig.yaml
kubectl get nodes
```

Optionally also fetch a talosconfig for `talosctl` access (useful for
`talosctl -n <ip> dashboard`/`logs` debugging):

```bash
mise run talos:testlab:talosconfig
export TALOSCONFIG=tofu/testlab/.cache/talosconfig
```

### 3. Bootstrap the ESO secret

External Secrets Operator can't resolve any `ExternalSecret` — including
its own `ClusterSecretStore` — until its 1Password service account token
exists in-cluster. This is the one secret that has to be created
out-of-band before anything else can manage secrets for itself:

```bash
mise run kubernetes:testlab:bootstrap
```

Requires the `1Password Service Account Auth Token: testlab k8s eso` item in the
`Home Network` 1Password vault (see
[`cluster-secret-store.yaml`](../kubernetes/testlab/apps/security-system/external-secrets/cluster-secret-store.yaml)).

### 4. Apply the full stack

```bash
mise run kubernetes:testlab:apply
```

Runs, in order: `render-metallb-config` (writes MetalLB's reserved LB IP
from tofu output) → `apply-volumesnapshot-crds` (applies the
`snapshot.storage.k8s.io` CRDs VolSync's controller requires at startup) →
`apply-crds` (pre-applies CRDs bundled by charts, via
[`bootstrap/crds/`](../kubernetes/testlab/bootstrap/crds/README.md)) →
`apply-charts` (`helmfile sync`) → `apply-manifests`
(`kubectl apply -k testlab`).

Talos ships no Traefik, no `local-path-provisioner`, and no default
CNI-agnostic Gateway API implementation the way k3s did — `apply-charts` now
installs `traefik` and `local-path-provisioner` as first-class releases
(see `kubernetes/testlab/helmfile.yaml`) to replace those former k3s
built-ins. Talos deploys its default Flannel CNI automatically; this repo
doesn't override that choice for `testlab`.

### 5. Verify

```bash
mise run kubernetes:testlab:validate    # schema-validates rendered output
kubectl get pods -A
kubectl get clustersecretstore onepassword   # should show Valid
kubectl get gatewayclass traefik            # should show ACCEPTED
kubectl get storageclass                    # local-path should show (default)
```

## Resource distribution

Living doc tracking how host resources are budgeted across the VMs for
each cluster in this repo. Updated whenever VM counts/sizes change.

## testlab

Runs entirely on the single [testlab host](hardware.md#testlab-host) (Intel
NUC6i5SYH, 2 cores / 4 threads, 32GB RAM, 1TB ZFS-backed `storage`
datastore, thick-provisioned). Its purpose is to validate the MetalLB +
Traefik Gateway API + Talos VIP pattern — stable, reserved IPs for both the
control plane (`talos_apiserver_vip`) and services (`k3s_lb_ip`) — in
isolation from the production `lab` cluster, ahead of building that same
pattern into `lab`. It does not test HA failover behavior; a single
controller and single worker are enough to prove the pattern, and real
multi-controller HA will be exercised on `lab` instead.

testlab originally ran k3s, installed via Ansible. It was rebuilt from
scratch (destroy + recreate, not an in-place upgrade — none exists between
k3s and Talos) onto Talos Linux, provisioned entirely by OpenTofu via the
[`siderolabs/talos`](https://registry.terraform.io/providers/siderolabs/talos/latest)
provider (`tofu/testlab/talos.tf`). VM provisioning uses a new
`tofu/modules/talos-vm` module, mirroring the existing `tofu/modules/ubuntu-vm`
module's shape but without any cloud-init/SSH concepts. `ansible/` remains
in the repo for any future Ubuntu-VM use; only its k3s/kube-vip-specific
playbooks were removed.

### Host RAM budget (32GB)

| Reservation        | Amount     | Why                                                                                                                                                                                                                    |
| ------------------ | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Proxmox host OS    | ~2 GB      | baseline hypervisor overhead                                                                                                                                                                                           |
| ZFS ARC (capped)   | ~6 GB      | caches the `storage` pool that backs the VM disks below — not unrelated overhead, so it isn't capped to near-zero. Set manually on the Proxmox host via `zfs_arc_max` in `/etc/modprobe.d/zfs.conf` (not tofu-managed) |
| **Usable for VMs** | **~24 GB** |                                                                                                                                                                                                                        |

### Host disk budget (`storage` pool, thick-provisioned)

Thick provisioning means every GB of `disk_size` is reserved immediately —
there's no overcommit safety net, so total requested size must stay under
physical capacity with headroom to spare (ZFS pools degrade in performance,
and risk filling up entirely, above ~80% used).

Actual pool capacity, per `zfs`/Proxmox reporting, is **965.56 GB** (not a
flat 1TB). There's also ~72.53 GB of non-VM overhead already on the pool
(templates, snapshots, etc.) that doesn't scale with VM disk size —
observed by comparing total pool usage against provisioned VM disk size
after the first sizing pass came in over budget.

| Reservation                   | Amount      | Why                                                        |
| ----------------------------- | ----------- | ---------------------------------------------------------- |
| Actual pool capacity          | 965.56 GB   | reported capacity, not nominal 1TB                         |
| ZFS free-space headroom (20%) | ~193.11 GB  | keeps the pool under ~80% used (772.45 GB ceiling)         |
| Non-VM overhead (observed)    | ~72.53 GB   | templates/snapshots/etc., fixed regardless of VM disk size |
| **Usable for VM disks**       | **~700 GB** |                                                            |

### Per-role VM sizing

Defined in `tofu/testlab/variables.tf`, applied via the `k3s_vm_controller`
and `k3s_vm_worker` module blocks in `tofu/testlab/main.tf`.

| Role       | Count | Cores each | Memory each      | Disk each | Memory total | Disk total |
| ---------- | ----- | ---------- | ---------------- | --------- | ------------ | ---------- |
| Controller | 1     | 2          | 6144 MB (6 GB)   | 80 GB     | 6 GB         | 80 GB      |
| Worker     | 1     | 2          | 18432 MB (18 GB) | 620 GB    | 18 GB        | 620 GB     |
| **Total**  | 2     | 4          |                  |           | **24 GB**    | **700 GB** |

4 vCPU total — the first topology here that doesn't oversubscribe the
host's 4 threads. The controller gets just enough for the OS, etcd, and the
Talos control plane; the worker gets the bulk of both budgets since it's
where Traefik, MetalLB's speaker, and test workloads actually run.

### Persistent storage

`local-path-provisioner` (a `helmfile.yaml` release, replacing what k3s
used to bundle by default) is the default StorageClass for general-purpose
PVCs, backed by the worker's local disk.

A separate `nfs.csi.k8s.io` StorageClass (`nfs-backups`, non-default,
`kubernetes/testlab/apps/storage-system/csi-driver-nfs`) is reserved for
shared/NFS-backed mounts (Jellyfin, Sonarr/Radarr, downloaders, etc.),
backed by a NAS rather than the worker's local disk.

## lab

Not yet implemented — see the [README goals](../README.md#goals). This
section will be filled in once the production cluster's host(s) and VM
topology are defined.
