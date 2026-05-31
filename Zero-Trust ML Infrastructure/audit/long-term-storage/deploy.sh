#!/usr/bin/env bash
# Deploy the audit and Falco S3 forwarders with Terraform outputs.
set -euo pipefail

: "${AUDIT_BUCKET:?set AUDIT_BUCKET to terraform output audit_bucket}"
: "${AUDIT_WRITER_ROLE_ARN:?set AUDIT_WRITER_ROLE_ARN to terraform output audit_writer_role_arn}"
: "${AWS_REGION:?set AWS_REGION}"
: "${CLUSTER_NAME:?set CLUSTER_NAME to terraform output cluster_name}"

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

sed \
  -e "s#arn:aws:iam::ACCOUNT_ID:role/zero-trust-ml-audit-writer#${AUDIT_WRITER_ROLE_ARN}#g" \
  -e "s#REPLACE_WITH_TF_OUTPUT_audit_bucket#${AUDIT_BUCKET}#g" \
  -e "s#us-west-2#${AWS_REGION}#g" \
  -e "s#zero-trust-ml#${CLUSTER_NAME}#g" \
  "$HERE/audit-forwarder.yaml" > "$TMP/audit-forwarder.yaml"

kubectl apply -f "$TMP/audit-forwarder.yaml"
