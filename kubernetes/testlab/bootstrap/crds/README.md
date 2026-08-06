# bootstrap/crds

CRDs that must exist before any Helm chart install can apply cleanly —
specifically, CRDs a chart bundles in its own `crds/` directory. `helm install`/`helmfile sync` handle a chart's bundled CRDs on first install, but
applying every chart's CRDs up front, before any release installs, avoids
CRD-size/ordering problems (a large CRD alongside its controller in the same
release can hit apply-ordering issues) and gives one clear pre-flight step
for standing up a fresh cluster.

`helmfile.yaml` in this directory lists the charts that bundle CRDs
(currently MetalLB, csi-driver-nfs, External Secrets Operator — see the
comment in that file for why others are excluded). It is
never `helmfile sync`'d; it exists only so `helmfile template` can render
each chart and its CRDs can be scraped out:

```sh
helmfile --file bootstrap/crds/helmfile.yaml template --include-crds \
  | yq ea 'select(.kind == "CustomResourceDefinition")' - \
  | kubectl apply --server-side --force-conflicts -f -
```

`--include-crds` is required — `helm`/`helmfile template` omit a chart's own
`crds/` directory by default (this is what previously caused the
OnePasswordItem CRD to be hand-vendored as a workaround under
`kustomize --enable-helm`; the fix is the same flag family, not a
kustomize-specific quirk).

Run this before `helmfile sync` on the root `../../helmfile.yaml` and before
`kubectl apply -k` on the raw manifests.

Versions here must be kept in sync by hand with the real releases in
`../../helmfile.yaml` — there's no automated link between the two files.

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
