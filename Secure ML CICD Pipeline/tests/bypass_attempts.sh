#!/usr/bin/env bash
# Bypass attempts. Each step MUST be rejected by the cluster's
# admission policies. If any "kubectl apply" succeeds, a control
# failed open.
set -uo pipefail

NS="${NS:-bypass-test}"
RUN_ID="${RUN_ID:-$(date +%s)}"
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

pass=0
fail=0
created=()

cleanup() {
  for pod in "${created[@]}"; do
    kubectl -n "$NS" delete pod "$pod" --ignore-not-found >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

expect_reject() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL  $name (admission allowed; control failed open)"
    fail=$((fail+1))
  else
    echo "OK    $name (rejected as expected)"
    pass=$((pass+1))
  fi
}

# 1) Unsigned image
created+=("u1-${RUN_ID}")
expect_reject "unsigned image" kubectl -n "$NS" run "u1-${RUN_ID}" \
  --image=nginx:latest --restart=Never

# 2) Signed image but no SBOM/SLSA attestation (an image signed
#    elsewhere, not by our pipeline).
created+=("u2-${RUN_ID}")
expect_reject "signed-but-no-attestation" kubectl -n "$NS" run "u2-${RUN_ID}" \
  --image=ghcr.io/sigstore/cosign/cosign:v2.2.0 --restart=Never

# 3) Attestation referencing the wrong commit / wrong workflow identity.
created+=("u3-${RUN_ID}")
MANIFEST=$(mktemp)
cat > "$MANIFEST" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: u3-${RUN_ID}
  namespace: ${NS}
spec:
  containers:
    - name: c
      image: ghcr.io/attacker/app:deadbeef
EOF
expect_reject "wrong-identity attestation" kubectl apply -f "$MANIFEST"
rm -f "$MANIFEST"

# 4) Model loaded without a valid cosign signature.
TMP=$(mktemp -d)
echo "fake-model" > "$TMP/model.bin"
if COSIGN_EXPERIMENTAL=1 cosign verify-blob \
      --signature /dev/null --certificate /dev/null \
      "$TMP/model.bin" >/dev/null 2>&1; then
  echo "FAIL  unsigned model (verify-blob accepted)"
  fail=$((fail+1))
else
  echo "OK    unsigned model (verify-blob rejected)"
  pass=$((pass+1))
fi
rm -rf "$TMP"

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
