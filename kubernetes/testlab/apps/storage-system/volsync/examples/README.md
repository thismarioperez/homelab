# VolSync rsync mover — example pattern

Reference-only manifests. They are not listed in any `kustomization.yaml`
and are never applied by `kubectl apply -k testlab` or the CI validation
pipeline. To adopt this pattern for a real app's PVC, copy both files,
rename them, and adjust `sourcePVC`, `capacity`, and the schedule.

## How this reaches the NAS

VolSync's rsync mover never talks to the NAS directly — it goes through
`nfs-backups` like any other PVC:

1. The `ReplicationDestination`'s `storageClassName: nfs-backups` causes
   `csi-driver-nfs` to dynamically provision the destination PVC as a
   subdirectory on the NAS share (`10.30.10.4:/volume1/kubernetes/testlab/backups`,
   see `../csi-driver-nfs/app/values.yaml`). This is the only point where
   NFS enters the picture.
1. VolSync runs a mover pod that mounts that destination PVC (a normal NFS
   mount via the CSI driver) and starts an rsync-over-SSH **server** in it,
   fronted by a ClusterIP `Service`.
1. The `ReplicationSource`'s mover pod mounts the **source** PVC (the real
   app's data volume) and runs rsync as an SSH **client**, pushing to the
   Destination's Service address.
1. So the data path is: source PVC → source mover pod → rsync/SSH over the
   pod network → destination mover pod → NFS mount → NAS.

## Apply order

VolSync's rsync mover pairs a `ReplicationDestination` (SSH server) with a
`ReplicationSource` (SSH client). The Destination must exist first because
it generates the SSH keypair `Secret` and Service address that the Source
needs to reference — there's no way to create both at once.

`replicationdestination.yaml` has no `trigger` set, so its SSH listener pod
stays up continuously — this is the correct shape for an ongoing backup
relationship, where the Source's `trigger.schedule` drives each sync. Only
add a `trigger.manual` to the Destination if it's for a genuine one-off
restore with no ongoing Source (see the comment in that file); doing so for
an ongoing relationship tears the listener down after the first sync and
scheduled pushes start failing with `ssh: connect ... Connection refused`.

1. Copy and adapt `replicationdestination.yaml` for the real app (rename,
   adjust `capacity`), then apply it:

   ```bash
   kubectl apply -f replicationdestination.yaml
   ```

1. Wait for VolSync to populate its status (the Service and SSH Secret are
   created asynchronously after the object is accepted):

   ```bash
   kubectl wait replicationdestination/<name> -n storage-system \
     --for=jsonpath='{.status.rsync.address}' --timeout=120s
   ```

1. Read the address and Secret name out of status:

   ```bash
   ADDRESS=$(kubectl get replicationdestination/<name> -n storage-system \
     -o jsonpath='{.status.rsync.address}')
   SSH_SECRET=$(kubectl get replicationdestination/<name> -n storage-system \
     -o jsonpath='{.status.rsync.sshKeys}')
   echo "address: $ADDRESS"
   echo "sshKeys: $SSH_SECRET"
   ```

1. Copy and adapt `replicationsource.yaml` for the real app (rename,
   `sourcePVC`, schedule), plug in `$ADDRESS`/`$SSH_SECRET` for the
   placeholder `address`/`sshKeys` fields, then apply it:

   ```bash
   kubectl apply -f replicationsource.yaml
   ```

These values are stable for the life of the `ReplicationDestination`
object, so this is a one-time wiring step per app, not something that
needs to be re-read on every backup run.

## Cleanup

The `nfs-backups` StorageClass uses `reclaimPolicy: Retain`, so PVs created
while testing this pattern are not automatically deleted when their PVC is
removed — clean up orphaned PVs manually.
