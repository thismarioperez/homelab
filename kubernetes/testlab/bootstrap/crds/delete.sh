#!/usr/bin/env bash
# Deletes every CRD applied by apply.sh (see helmfile.yaml in this
# directory for the full chart list). Deleting a CRD cascade-deletes every
# custom resource of that kind cluster-wide, so this is intentionally a
# separate, explicit step from `helmfile destroy` — never run automatically
# as part of a normal release teardown.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

helmfile --file helmfile.yaml list --output json 2>/dev/null \
  | yq -p json -o json '.[]' -I0 \
  | while read -r entry; do
      crds_name=$(echo "$entry" | yq '.name' -)

      names=$(helmfile --file helmfile.yaml template --include-crds --selector name="$crds_name" 2>/dev/null \
        | yq ea 'select(.kind == "CustomResourceDefinition") | .metadata.name' - \
        | grep -v '^---$' || true)

      [ -z "$names" ] && continue

      echo "$names" | xargs -I{} kubectl delete crd {} --ignore-not-found
    done
