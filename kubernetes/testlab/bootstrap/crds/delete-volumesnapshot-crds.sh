#!/usr/bin/env bash
# Deletes the CRDs applied by apply-volumesnapshot-crds.sh. Deleting a CRD
# cascade-deletes every custom resource of that kind cluster-wide, so this
# is intentionally a separate, explicit step — never run automatically as
# part of a normal release teardown.
set -euo pipefail

for crd in \
  volumesnapshotclasses.snapshot.storage.k8s.io \
  volumesnapshotcontents.snapshot.storage.k8s.io \
  volumesnapshots.snapshot.storage.k8s.io; do
  kubectl delete crd "$crd" --ignore-not-found
done
