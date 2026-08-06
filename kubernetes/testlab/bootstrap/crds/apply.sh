#!/usr/bin/env bash
# Applies each chart's CRDs (via helmfile.yaml in this directory) and stamps
# them with the owning release's Helm ownership metadata, so that the real
# `helm install` in ../../helmfile.yaml can adopt them instead of refusing
# with "invalid ownership metadata" — kubectl apply --server-side alone
# does not set app.kubernetes.io/managed-by or the meta.helm.sh/release-*
# annotations that Helm 3 requires to adopt a pre-existing CRD.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

helmfile --file helmfile.yaml list --output json 2>/dev/null \
  | yq -p json -o json '.[]' -I0 \
  | while read -r entry; do
      crds_name=$(echo "$entry" | yq '.name' -)
      namespace=$(echo "$entry" | yq '.namespace' -)
      release="${crds_name%-crds}"

      crds=$(helmfile --file helmfile.yaml template --include-crds --selector name="$crds_name" 2>/dev/null \
        | yq ea 'select(.kind == "CustomResourceDefinition")' -)

      [ -z "$crds" ] && continue

      echo "$crds" | kubectl apply --server-side --force-conflicts -f -

      echo "$crds" | yq ea '.metadata.name' - | grep -v '^---$' | while read -r name; do
        kubectl label crd "$name" app.kubernetes.io/managed-by=Helm --overwrite
        kubectl annotate crd "$name" \
          meta.helm.sh/release-name="$release" \
          meta.helm.sh/release-namespace="$namespace" \
          --overwrite
      done
    done
