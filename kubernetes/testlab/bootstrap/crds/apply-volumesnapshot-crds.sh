#!/usr/bin/env bash
# VolSync's controller hard-requires the snapshot.storage.k8s.io CRDs
# (VolumeSnapshot/VolumeSnapshotClass/VolumeSnapshotContent) to exist at
# startup and crashloops without them — even though this repo never uses
# VolSync's Snapshot copyMethod, only Direct (see
# ../../apps/storage-system/volsync/examples/README.md). Those CRDs aren't
# bundled by VolSync's own chart (or any chart in helmfile.yaml); they come
# from the separate kubernetes-csi/external-snapshotter project, so they
# can't go through the helmfile-template extraction that apply.sh/delete.sh
# use for chart-bundled CRDs. This is a standalone step for that reason.
set -euo pipefail

VOLSYNC_SNAPSHOTTER_VERSION="v8.6.0"
BASE_URL="https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/${VOLSYNC_SNAPSHOTTER_VERSION}/client/config/crd"

for crd in \
  snapshot.storage.k8s.io_volumesnapshotclasses.yaml \
  snapshot.storage.k8s.io_volumesnapshotcontents.yaml \
  snapshot.storage.k8s.io_volumesnapshots.yaml; do
  kubectl apply --server-side -f "${BASE_URL}/${crd}"
done
