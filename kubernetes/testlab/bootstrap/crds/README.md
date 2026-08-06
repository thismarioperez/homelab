# bootstrap/crds

CRDs that must exist before any Helm chart install can apply cleanly —
specifically, CRDs a chart bundles in its own `crds/` directory. `helm install`/`helmfile sync` handle a chart's bundled CRDs on first install, but
applying every chart's CRDs up front, before any release installs, avoids
CRD-size/ordering problems (a large CRD alongside its controller in the same
release can hit apply-ordering issues) and gives one clear pre-flight step
for standing up a fresh cluster.

`helmfile.yaml` in this directory lists the charts that bundle CRDs
(currently MetalLB, csi-driver-nfs, External Secrets Operator, VolSync —
see the comment in that file for why others are excluded). It is
never `helmfile sync`'d; it exists only so `helmfile template` can render
each chart and its CRDs can be scraped out and applied via `apply.sh`:

```sh
./bootstrap/crds/apply.sh
```

`--include-crds` is required — `helm`/`helmfile template` omit a chart's own
`crds/` directory by default (this is what previously caused the
OnePasswordItem CRD to be hand-vendored as a workaround under
`kustomize --enable-helm`; the fix is the same flag family, not a
kustomize-specific quirk).

Plain `kubectl apply --server-side` does not stamp the
`app.kubernetes.io/managed-by: Helm` label or `meta.helm.sh/release-*`
annotations that Helm 3 requires to adopt a pre-existing resource — without
them, the real `helm install` in `../../helmfile.yaml` fails with
`invalid ownership metadata` the first time it tries to install a chart
whose CRDs were already applied here. `apply.sh` applies each chart's CRDs
per-release (not as one combined batch) and stamps them with that release's
ownership metadata immediately after, so `helmfile sync` can adopt them
cleanly.

Run this before `helmfile sync` on the root `../../helmfile.yaml` and before
`kubectl apply -k` on the raw manifests.

Versions here must be kept in sync by hand with the real releases in
`../../helmfile.yaml` — there's no automated link between the two files.

## VolumeSnapshot CRDs

VolSync's controller hard-requires the `snapshot.storage.k8s.io` CRDs
(`VolumeSnapshot`/`VolumeSnapshotClass`/`VolumeSnapshotContent`) to exist at
startup, and crashloops without them — even though this repo only uses
VolSync's `Direct` copyMethod, never `Snapshot`
(see [`../../apps/storage-system/volsync/examples/README.md`](../../apps/storage-system/volsync/examples/README.md)).
Those CRDs aren't bundled by VolSync's own chart (or any chart in
`helmfile.yaml`) — they come from the separate
[`kubernetes-csi/external-snapshotter`](https://github.com/kubernetes-csi/external-snapshotter)
project, so they can't go through the `helmfile template --include-crds`
extraction `apply.sh`/`delete.sh` use. Apply them as their own step, before
`apply.sh`:

```sh
./bootstrap/crds/apply-volumesnapshot-crds.sh
```

The pinned version lives in that script (`VOLSYNC_SNAPSHOTTER_VERSION`) and
must be bumped by hand — same manual-sync caveat as the Helm chart versions
above.

## Migrating to Flux

If this cluster moves from local `helmfile sync` to Flux (`HelmRelease`
reconciled in-cluster), this directory stops being needed:
`HelmRelease.spec.install.crds: CreateReplace` (and `spec.upgrade.crds`)
handles a chart's bundled CRDs per-release natively, replacing what this
extraction step is for today.

The one thing that still needs a one-time local bootstrap step under Flux
(same pattern as home-ops-style repos) is Flux itself — its own CRDs plus
`flux-operator`/`flux-instance` have to exist before Flux can reconcile
anything, including itself. That bootstrap would live in a new top-level
`bootstrap/flux/` dir (sibling to this one), not here.

Each release in `../../helmfile.yaml` maps directly onto a
`HelmRepository`/`OCIRepository` + `HelmRelease` pair — no redesign needed:
`chart`/`version` becomes the repository ref, and each app's
`app/values.yaml` becomes `HelmRelease.spec.values` verbatim (same file,
same content, different consumer). Every `kustomization.yaml` (root and
per-namespace) carries over unchanged and becomes the `path:` target of a
Flux `Kustomization` CR.
