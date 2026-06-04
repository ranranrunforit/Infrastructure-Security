#!/usr/bin/env bash
# Sign model artifacts after training and publish them to an OCI registry.
set -euo pipefail

MODEL_PATH="${1:?usage: sign_model.sh MODEL_PATH MODEL_REF}"
MODEL_REF="${2:?usage: sign_model.sh MODEL_PATH MODEL_REF}"
SHA=$(sha256sum "$MODEL_PATH" | awk '{print $1}')

oras push "$MODEL_REF" "$MODEL_PATH:application/vnd.secureml.model"
if [[ "$MODEL_REF" == *@sha256:* ]]; then
  MODEL_SUBJECT="$MODEL_REF"
else
  MODEL_DIGEST=$(oras resolve "$MODEL_REF")
  MODEL_SUBJECT="${MODEL_REF}@${MODEL_DIGEST}"
fi
COSIGN_EXPERIMENTAL=1 cosign sign --yes "$MODEL_SUBJECT"
COSIGN_EXPERIMENTAL=1 cosign sign-blob --yes \
  --output-signature "${MODEL_PATH}.sig" \
  --output-certificate "${MODEL_PATH}.cert" \
  "$MODEL_PATH"

AUDIT_FILE=$(mktemp)
trap 'rm -f "$AUDIT_FILE"' EXIT
cat > "$AUDIT_FILE" <<EOF
{
  "model_ref": "$MODEL_SUBJECT",
  "model_sha256": "$SHA",
  "action": "model-registry-sign"
}
EOF
COSIGN_EXPERIMENTAL=1 cosign attest --yes \
  --type secureml.model.audit/v1 \
  --predicate "$AUDIT_FILE" \
  "$MODEL_SUBJECT"
rm -f "$AUDIT_FILE"
trap - EXIT

echo "signed: $MODEL_PATH"
echo "  registry: $MODEL_SUBJECT"
echo "  sha256: $SHA"
echo "  signature: ${MODEL_PATH}.sig"
