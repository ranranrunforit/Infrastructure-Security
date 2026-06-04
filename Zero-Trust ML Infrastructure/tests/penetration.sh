#!/usr/bin/env bash
# Penetration test: attempt each attack; expect all runnable attacks to fail.
set -uo pipefail

PASS=0
FAIL=0
SKIP=0
RUN_ID="${RUN_ID:-$(date +%s)}"
TMP_DIR="$(mktemp -d)"
CREATED_PODS=()

cleanup() {
  for item in "${CREATED_PODS[@]}"; do
    kubectl -n "${item%%:*}" delete pod "${item#*:}" --ignore-not-found >/dev/null 2>&1 || true
  done
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

pass() {
  echo "[PASS] $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "[FAIL] $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo "[SKIP] $1"
  SKIP=$((SKIP + 1))
}

expect_blocked() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    fail "$name succeeded"
  else
    pass "$name blocked"
  fi
}

apply_blocked_manifest() {
  local name="$1"
  local file="$2"
  expect_blocked "$name" kubectl apply -f "$file"
}

echo "Test 1: cross-tenant secret read"
expect_blocked "Cross-tenant secret read" \
  kubectl --as=user:team-a:dev get secret -n team-b

echo "Test 2: deploy unsigned image"
UNSIGNED_POD="unsigned-test-${RUN_ID}"
CREATED_PODS+=("iris:${UNSIGNED_POD}")
cat > "$TMP_DIR/unsigned.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${UNSIGNED_POD}
  namespace: iris
  labels: { owner: security-test, tier: ml }
spec:
  securityContext: { runAsNonRoot: true }
  containers:
    - name: c
      image: random/unsigned:latest
      securityContext: { runAsNonRoot: true, allowPrivilegeEscalation: false }
EOF
apply_blocked_manifest "Unsigned image deploy" "$TMP_DIR/unsigned.yaml"

echo "Test 3: deploy root container"
if [ -z "${SIGNED_TEST_IMAGE_DIGEST:-}" ]; then
  skip "set SIGNED_TEST_IMAGE_DIGEST to a trusted signed digest to test root-container admission"
else
  ROOT_POD="root-test-${RUN_ID}"
  CREATED_PODS+=("iris:${ROOT_POD}")
  cat > "$TMP_DIR/root.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${ROOT_POD}
  namespace: iris
  labels: { owner: security-test, tier: ml }
spec:
  containers:
    - name: c
      image: ${SIGNED_TEST_IMAGE_DIGEST}
      securityContext: { runAsNonRoot: false, allowPrivilegeEscalation: true }
EOF
  apply_blocked_manifest "Root container deploy" "$TMP_DIR/root.yaml"
fi

echo "Test 4: deploy host namespace pod"
if [ -z "${SIGNED_TEST_IMAGE_DIGEST:-}" ]; then
  skip "set SIGNED_TEST_IMAGE_DIGEST to a trusted signed digest to test host-namespace admission"
else
  HOST_POD="hostns-test-${RUN_ID}"
  CREATED_PODS+=("iris:${HOST_POD}")
  cat > "$TMP_DIR/hostns.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${HOST_POD}
  namespace: iris
  labels: { owner: security-test, tier: ml }
spec:
  hostNetwork: true
  securityContext: { runAsNonRoot: true }
  containers:
    - name: c
      image: ${SIGNED_TEST_IMAGE_DIGEST}
      securityContext: { runAsNonRoot: true, allowPrivilegeEscalation: false }
EOF
  apply_blocked_manifest "Host namespace deploy" "$TMP_DIR/hostns.yaml"
fi

echo "Test 5: spawn shell in ML pod"
POD=$(kubectl get pod -n iris -l app=iris-api -o name 2>/dev/null | head -1)
if [ -n "$POD" ]; then
  kubectl exec -n iris "$POD" -- /bin/sh -c "echo testing" >/dev/null 2>&1
  sleep 5
  if kubectl logs -n falco daemonset/falco --since=2m 2>/dev/null | grep -q "Shell in ML pod"; then
    pass "Falco shell alert fired"
  else
    fail "Falco shell alert missing"
  fi
else
  fail "iris-api pod not found"
fi

echo "Test 6: lateral movement"
if [ -n "${PROBE_POD:-}" ]; then
  expect_blocked "Cross-namespace HTTP" \
    kubectl exec -n team-a "$PROBE_POD" -- curl -m 3 "${TEAM_B_URL:-http://service.team-b.svc}"
elif [ -n "${PROBE_IMAGE_DIGEST:-}" ]; then
  PROBE_NAME="probe-${RUN_ID}"
  CREATED_PODS+=("team-a:${PROBE_NAME}")
  cat > "$TMP_DIR/probe.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${PROBE_NAME}
  namespace: team-a
  labels: { owner: security-test, tier: debug }
spec:
  securityContext: { runAsNonRoot: true }
  containers:
    - name: curl
      image: ${PROBE_IMAGE_DIGEST}
      command: ["sleep", "300"]
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        allowPrivilegeEscalation: false
EOF
  if kubectl apply -f "$TMP_DIR/probe.yaml" >/dev/null 2>&1; then
    if kubectl wait -n team-a --for=condition=Ready "pod/${PROBE_NAME}" --timeout=60s >/dev/null 2>&1; then
      expect_blocked "Cross-namespace HTTP" \
        kubectl exec -n team-a "$PROBE_NAME" -- curl -m 3 "${TEAM_B_URL:-http://service.team-b.svc}"
    else
      fail "Probe pod did not become Ready before NetworkPolicy could be tested"
    fi
  else
    fail "Probe pod setup failed before NetworkPolicy could be tested"
  fi
else
  skip "set PROBE_POD or PROBE_IMAGE_DIGEST to test NetworkPolicy lateral movement"
fi

echo "Test 7: plaintext secret scan"
if rg -i "(password|token|secret|apikey|api_key):\\s*['\\\"]?[A-Za-z0-9_./+=-]{8,}" \
    --glob "*.yaml" --glob "*.yml" --glob "!secrets/vault-eso.yaml" .; then
  fail "Plaintext secret found"
else
  pass "Plaintext secret scan clean"
fi

echo "Test 8: audit hash-chain verification"
if [ -n "${AUDIT_LOG_DIR:-}" ] && [ -f "${AUDIT_CHAIN_FILE:-}" ]; then
  if python3 audit/hash-chain.py verify --chain "$AUDIT_CHAIN_FILE" "$AUDIT_LOG_DIR"/*; then
    pass "Audit hash-chain verified"
  else
    fail "Audit hash-chain verification failed"
  fi
else
  skip "set AUDIT_LOG_DIR and AUDIT_CHAIN_FILE to verify exported logs"
fi

echo "---"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Skipped: $SKIP"
exit "$FAIL"
