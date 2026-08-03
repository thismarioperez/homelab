# Kubernetes Resource Distribution

Living doc tracking how host resources are budgeted across the k3s VMs for
each cluster in this repo. Updated whenever VM counts/sizes change.

## testlab

Runs entirely on the single [testlab host](hardware.md#testlab-host) (Intel
NUC6i5SYH, 2 cores / 4 threads, 32GB RAM, 1TB ZFS-backed `storage`
datastore, thick-provisioned). Its purpose is to validate the MetalLB +
Traefik Gateway API + kube-vip pattern — stable, reserved IPs for both the
control plane (`k3s_apiserver_vip`) and services (`k3s_lb_ip`) — in
isolation from the production `lab` cluster, ahead of building that same
pattern into `lab`. It does not test HA failover behavior; a single
controller and single worker are enough to prove the pattern, and real
multi-controller HA will be exercised on `lab` instead.

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
host's 4 threads. The controller gets just enough for the OS, etcd, k3s
server, and kube-vip; the worker gets the bulk of both budgets since it's
where Traefik, MetalLB's speaker, and test workloads actually run.

### Persistent storage

[Longhorn](https://longhorn.io) (`kubernetes/testlab/apps/longhorn`) is the
default StorageClass for general-purpose PVCs. `defaultReplicaCount` is set
to 1 since the cluster runs a single worker — Longhorn provides a CSI layer
over local disk here, not replication/HA.

A separate `nfs.csi.k8s.io` StorageClass (non-default) is reserved for
shared media mounts (Jellyfin, Sonarr/Radarr, downloaders, etc.), backed by
a NAS rather than the worker's local disk.

## lab

Not yet implemented — see the [README goals](../README.md#goals). This
section will be filled in once the production cluster's host(s) and VM
topology are defined.
