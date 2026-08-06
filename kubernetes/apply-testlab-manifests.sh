#!/usr/bin/env bash
# Retries `kubectl apply -k testlab` a few times: pod Ready doesn't
# guarantee a webhook's TLS listener inside is already accepting
# connections — both ESO's and MetalLB's validating webhooks have raced
# this on a fresh install (502/no-endpoints briefly after the pod goes
# Ready), and the wait-eso-webhook/wait-metallb-webhook mise tasks can't
# fully close that gap since they can only observe pod readiness, not
# webhook-server readiness.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

attempts=5
for i in $(seq 1 "$attempts"); do
  if kubectl apply -k testlab; then
    exit 0
  fi
  echo "apply-testlab-manifests attempt $i/$attempts failed, retrying in 5s..." >&2
  sleep 5
done

echo "apply-testlab-manifests failed after $attempts attempts" >&2
exit 1
