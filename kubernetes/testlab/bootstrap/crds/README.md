# bootstrap/crds

Placeholder for CRDs that must exist before any `helmCharts:`/CR-bearing
kustomization can apply cleanly — i.e. CRDs not already vendored by a
chart's own `helm template` output and not otherwise pre-installed by the
cluster.

Nothing needs this today:

- MetalLB's CRDs render as part of its own chart (a `charts/crds`
  subchart), picked up automatically by `--enable-helm` alongside
  `apps/metallb-system`.
- Gateway API's CRDs are installed implicitly by k3s's embedded Traefik
  chart once `apps/kube-system/helmchartconfig.yaml` enables
  `providers.kubernetesGateway`.

If a future chart/CR needs a CRD applied ahead of everything else, add it
here and reference `bootstrap/crds` first in the root
`kubernetes/testlab/kustomization.yaml`'s `resources:` list.

## Migrating to Flux

If this cluster moves from local `kustomize --enable-helm` to Flux
(`HelmRelease` reconciled in-cluster), this directory mostly stops being
needed: `HelmRelease.spec.install.crds: CreateReplace` handles chart-bundled
CRDs per-release natively, replacing what this placeholder is for today.

The one thing that still needs a one-time local-helm bootstrap step (same
pattern as home-ops-style repos) is Flux itself — its own CRDs plus
`flux-operator`/`flux-instance` have to exist before Flux can reconcile
anything, including itself. That bootstrap would live in a new top-level
`bootstrap/` dir (sibling to `apps/`), not here.

Each app's existing `helmCharts:` entry (name/repo/version/releaseName/
namespace/valuesInline) maps directly onto a `HelmRepository` +
`HelmRelease` pair — no redesign needed, just delete the `helmCharts:`
stanza and add the matching CRs. Static resources (`namespace.yaml`,
`ipaddresspool.yaml`, `httproute.yaml`, etc.) carry over unchanged.
