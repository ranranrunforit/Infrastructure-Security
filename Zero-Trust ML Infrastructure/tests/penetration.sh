#!/usr/bin/env bash
# Penetration test: attempt each attack; expect all to fail.
set -uo pipefail
PASS=0
FAIL=0

check() {
    if eval "$1"; then
        echo "[FAIL] $2 succeeded"
        FAIL=$((FAIL + 1))
    else
        echo "[PASS] $2 blocked"
        PASS=$((PASS + 1))
    fi
}

echo "Test 1: cross-tenant secret read"
check 'kubectl --as=user:team-a:dev get secret -n team-b' \
      "Cross-tenant secret read"

echo "Test 2: deploy unsigned image"
check 'kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: unsigned-test
  namespace: iris
  labels: { owner: security-test, tier: ml }
spec:
  securityContext: { runAsNonRoot: true }
  containers:
    - name: c
      image: random/unsigned:latest
      securityContext: { runAsNonRoot: true, allowPrivilegeEscalation: false }
EOF' "Unsigned image deploy"

echo "Test 3: deploy root container"
check 'kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: root-test
  namespace: iris
  labels: { owner: security-test, tier: ml }
spec:
  containers:
    - name: c
      image: registry.example.com/ml/iris-api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      securityContext: { runAsNonRoot: false, allowPrivilegeEscalation: true }
EOF' "Root container deploy"

echo "Test 4: deploy host namespace pod"
check 'kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hostns-test
  namespace: iris
  labels: { owner: security-test, tier: ml }
spec:
  hostNetwork: true
  securityContext: { runAsNonRoot: true }
  containers:
    - name: c
      image: registry.example.com/ml/iris-api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      securityContext: { runAsNonRoot: true, allowPrivilegeEscalation: false }
EOF' "Host namespace deploy"

echo "Test 5: spawn shell in ML pod"
POD=$(kubectl get pod -n iris -l app=iris-api -o name | head -1)
if [ -n "$POD" ]; then
    kubectl exec -n iris "$POD" -- /bin/sh -c "echo testing" 2>/dev/null
    sleep 5
    if kubectl logs -n falco daemonset/falco | grep -q "Shell in ML pod"; then
        echo "[PASS] Falco shell alert fired"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] Falco shell alert missing"
        FAIL=$((FAIL + 1))
    fi
else
    echo "[FAIL] iris-api pod not found"
    FAIL=$((FAIL + 1))
fi

echo "Test 6: lateral movement"
check 'kubectl run -n team-a probe --rm -i --restart=Never --image=curlimages/curl -- curl -m 3 http://service.team-b.svc' \
      "Cross-namespace HTTP"

echo "Test 7: plaintext secret scan"
if rg -i "(password|token|secret|apikey|api_key):\\s*['\\\"]?[A-Za-z0-9_./+=-]{8,}" \
    --glob "*.yaml" --glob "*.yml" --glob "!secrets/vault-eso.yaml" .; then
    echo "[FAIL] Plaintext secret found"
    FAIL=$((FAIL + 1))
else
    echo "[PASS] Plaintext secret scan clean"
    PASS=$((PASS + 1))
fi

echo "Test 8: audit hash-chain verification"
if [ -n "${AUDIT_LOG_DIR:-}" ] && [ -f "${AUDIT_CHAIN_FILE:-}" ]; then
    if python3 audit/hash-chain.py verify --chain "$AUDIT_CHAIN_FILE" "$AUDIT_LOG_DIR"/*; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
else
    echo "[SKIP] set AUDIT_LOG_DIR and AUDIT_CHAIN_FILE to verify exported logs"
fi

echo "---"
echo "Passed: $PASS"
echo "Failed: $FAIL"
exit "$FAIL"
