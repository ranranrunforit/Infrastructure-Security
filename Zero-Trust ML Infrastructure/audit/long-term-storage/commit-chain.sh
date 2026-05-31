#!/usr/bin/env bash
# Build the hash chain for a downloaded audit prefix and upload the chain file
# into the Object Lock bucket. Run this after a closed audit window, for
# example hourly or daily.
set -euo pipefail

: "${AUDIT_BUCKET:?set AUDIT_BUCKET to terraform output audit_bucket}"
PREFIX="${1:-k8s-audit/}"
CHAIN_KEY="${CHAIN_KEY:-${PREFIX%/}/chain.json}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

aws s3 sync "s3://${AUDIT_BUCKET}/${PREFIX}" "$WORKDIR/logs" \
  --exclude "chain.json" \
  --no-progress

find "$WORKDIR/logs" -name '*.gz' -exec gunzip -k {} +
mapfile -t LOGS < <(find "$WORKDIR/logs" -type f ! -name '*.gz' | sort)

if [ "${#LOGS[@]}" -eq 0 ]; then
  echo "no audit objects downloaded from s3://${AUDIT_BUCKET}/${PREFIX}" >&2
  exit 1
fi

python3 "$(dirname "$0")/../hash-chain.py" build \
  --chain "$WORKDIR/chain.json" \
  "${LOGS[@]}"

aws s3 cp "$WORKDIR/chain.json" "s3://${AUDIT_BUCKET}/${CHAIN_KEY}" \
  --content-type application/json \
  --no-progress
