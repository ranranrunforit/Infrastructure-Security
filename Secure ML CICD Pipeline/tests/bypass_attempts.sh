#!/usr/bin/env bash
# Bypass attempts. Each step MUST be rejected by the cluster's
# admission policies. If any "kubectl apply" succeeds, a control
# failed open.
set -uo pipefail

NS="${NS:-bypass-test}"
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

pass=0
fail=0
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
expect_reject "unsigned image" kubectl -n "$NS" run u1 \
  --image=nginx:latest --restart=Never

# 2) Signed image but no SBOM/SLSA attestation (an image signed
#    elsewhere, not by our pipeline).
expect_reject "signed-but-no-attestation" kubectl -n "$NS" run u2 \
  --image=ghcr.io/sigstore/cosign/cosign:v2.2.0 --restart=Never

# 3) Attestation referencing the wrong commit / wrong workflow identity.
cat <<'EOF' | expect_reject "wrong-identity attestation" kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: u3, namespace: bypass-test }
spec:
  containers:
    - name: c
      image: ghcr.io/attacker/app:deadbeef
EOF

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
