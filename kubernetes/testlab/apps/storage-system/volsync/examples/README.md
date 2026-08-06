# VolSync rsync mover — example pattern

Reference-only manifests. They are not listed in any `kustomization.yaml`
and are never applied by `kubectl apply -k testlab` or the CI validation
pipeline. To adopt this pattern for a real app's PVC, copy both files,
rename them, and adjust `sourcePVC`, `capacity`, and the schedule.

## Apply order

VolSync's rsync mover pairs a `ReplicationDestination` (SSH server) with a
`ReplicationSource` (SSH client):

1. Apply `replicationdestination.yaml` first. VolSync generates an SSH
   keypair `Secret` and publishes the connection info at
   `.status.rsync.address` and `.status.rsync.sshKeys`.
1. Read those status fields and use them as the `address`/`sshKeys` values
   in `replicationsource.yaml` before applying it — the values in this
   example are placeholders showing the expected shape, not real values.

## Cleanup

The `nfs-backups` StorageClass uses `reclaimPolicy: Retain`, so PVs created
while testing this pattern are not automatically deleted when their PVC is
removed — clean up orphaned PVs manually.
