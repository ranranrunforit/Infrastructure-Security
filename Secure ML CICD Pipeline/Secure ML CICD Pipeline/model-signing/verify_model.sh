#!/usr/bin/env bash
# Run at serving startup. Exit non-zero -> serving must refuse to load.
set -euo pipefail

MODEL_PATH="${1:?usage: verify_model.sh MODEL_PATH MODEL_REF}"
MODEL_REF="${2:?usage: verify_model.sh MODEL_PATH MODEL_REF_DIGEST}"
IDENTITY="${COSIGN_IDENTITY:?set to the training workflow identity}"
ISSUER="${COSIGN_ISSUER:-https://token.actions.githubusercontent.com}"

COSIGN_EXPERIMENTAL=1 cosign verify "$MODEL_REF" \
  --certificate-identity "$IDENTITY" \
  --certificate-oidc-issuer "$ISSUER"

COSIGN_EXPERIMENTAL=1 cosign verify-blob \
  --signature "${MODEL_PATH}.sig" \
  --certificate "${MODEL_PATH}.cert" \
  --certificate-identity "$IDENTITY" \
  --certificate-oidc-issuer "$ISSUER" \
  "$MODEL_PATH"
echo "verified: $MODEL_PATH"
echo "verified registry signature: $MODEL_REF"
