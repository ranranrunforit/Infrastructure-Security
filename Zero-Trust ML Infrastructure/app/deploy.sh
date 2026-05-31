#!/usr/bin/env bash
# Deploy the iris API with the signed image digest required by Kyverno.
set -euo pipefail

: "${SIGNED_IMAGE_DIGEST:?set SIGNED_IMAGE_DIGEST, for example ghcr.io/org/iris-api@sha256:...}"

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

sed "s#ghcr.io/example/ml-platform/iris-api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#${SIGNED_IMAGE_DIGEST}#g" \
  "$HERE/kubernetes/iris-api.yaml" > "$TMP/iris-api.yaml"

kubectl apply -f "$TMP/iris-api.yaml"
kubectl apply -f "$HERE/kubernetes/ingress-gateway.yaml"
