#!/usr/bin/env bash
# Install the seven zero-trust platform dependencies in the order expected
# by the manifests in this repo. Idempotent: each step uses `helm upgrade
# --install`. Assumes kubectl is already pointed at the target cluster.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
API_SERVER_HOST="${K8S_SERVICE_HOST:-$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed -E 's#^https://([^:/]+).*#\1#')}"

helm repo add cilium           https://helm.cilium.io                  >/dev/null
helm repo add istio            https://istio-release.storage.googleapis.com/charts >/dev/null
helm repo add spiffe           https://spiffe.github.io/helm-charts-hardened >/dev/null
helm repo add hashicorp        https://helm.releases.hashicorp.com     >/dev/null
helm repo add external-secrets https://charts.external-secrets.io      >/dev/null
helm repo add kyverno          https://kyverno.github.io/kyverno       >/dev/null
helm repo add falcosecurity    https://falcosecurity.github.io/charts  >/dev/null
helm repo update >/dev/null

# 1. Cilium (CNI + microsegmentation). Replace kube-proxy with eBPF.
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  -f "$HERE/cilium-values.yaml" \
  --set "k8sServiceHost=${API_SERVER_HOST}"

# 2. Istio (mesh + mTLS).
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install istio-base istio/base \
  --namespace istio-system \
  -f "$HERE/istio-base-values.yaml"
helm upgrade --install istiod istio/istiod \
  --namespace istio-system \
  -f "$HERE/istiod-values.yaml"

# 3. SPIRE (workload identity).
kubectl create namespace spire --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install spire spiffe/spire \
  --namespace spire \
  -f "$HERE/spire-values.yaml"

# 4. Vault (secrets backend).
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  -f "$HERE/vault-values.yaml"

# 5. External Secrets Operator (Vault -> Kubernetes Secret).
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  -f "$HERE/external-secrets-values.yaml"

# 6. Kyverno (admission policy).
kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  -f "$HERE/kyverno-values.yaml"

# 7. Falco (runtime detection).
kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install falco falcosecurity/falco \
  --namespace falco \
  -f "$HERE/falco-values.yaml" \
  --set-file "customRules.ml-platform\.yaml=$HERE/../falco-rules/ml-platform.yaml"

echo "All seven components installed. Apply repo manifests next:"
echo "  kubectl apply -f istio/ network-policies/ secrets/ policies/"
