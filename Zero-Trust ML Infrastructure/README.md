# Zero-Trust ML Infrastructure

This folder contains a Kubernetes-based reference implementation for a
zero-trust ML platform. The goal is to make every service-to-service and
tenant-to-platform interaction authenticated, authorized, encrypted, and
auditable.

The implementation is intentionally focused on the security controls in this
folder: Cilium network policies, Istio mTLS and authorization, SPIRE workload
identity, Vault-backed secrets through External Secrets Operator, Kyverno
admission policy, Falco runtime detection, and audit hash-chain verification.

## Architecture

```text
External user/service
  -> ingress service account
  -> Istio AuthorizationPolicy
  -> STRICT Istio mTLS
  -> SPIFFE/SPIRE workload identity
  -> Cilium default-deny network boundary
  -> Vault-backed secrets through ESO
  -> Kyverno admission gates
  -> Falco runtime alerts
  -> Kubernetes audit log + hash chain
```

There is no implicit namespace trust. Workloads must pass both network-layer
allow rules and mesh-layer authorization. Secrets are referenced from Vault
instead of stored directly in manifests. Runtime behavior is monitored after
admission.

## Repository Layout

```text
Zero-Trust ML Infrastructure/
|-- README.md                       # Project overview and usage guide
|-- REQUIREMENTS.md                 # Project requirements
|-- ARCHITECTURE.md                 # Zero-trust architecture notes
|-- terraform/                      # VPC + EKS + audit S3 + IAM (IRSA)
|   |-- versions.tf                 # Terraform and provider version constraints
|   |-- variables.tf                # Cluster, VPC, node, audit bucket inputs
|   |-- main.tf                     # AWS/Kubernetes/Helm provider configuration
|   |-- vpc.tf                      # VPC, private/public subnets, flow logs
|   |-- eks.tf                      # EKS cluster, node group, audit log enablement
|   |-- audit-storage.tf            # S3 + Object Lock (COMPLIANCE) + IAM
|   `-- outputs.tf                  # Cluster, bucket, and IRSA role outputs
|-- helm/                           # Install Cilium, Istio, SPIRE, Vault,
|   |-- install.sh                  #   ESO, Kyverno, and Falco via Helm.
|   |-- cilium-values.yaml          # WireGuard encryption + kube-proxy replacement
|   |-- istio-base-values.yaml      # Istio CRD/base chart values
|   |-- istiod-values.yaml          # Istio control plane and trust domain values
|   |-- spire-values.yaml           # SPIRE trust domain and workload identity values
|   |-- vault-values.yaml           # Vault HA Raft values
|   |-- external-secrets-values.yaml # ESO controller values
|   |-- kyverno-values.yaml         # Kyverno HA and failurePolicy settings
|   `-- falco-values.yaml           # Falco modern eBPF and JSON output values
|-- app/                            # Minimal protected ML application
|   |-- iris-api/                   # Inference service source and image build
|   |   |-- app.py                  # Minimal ML inference API
|   |   `-- Dockerfile              # Non-root Python runtime image
|   |-- kubernetes/                 # Kubernetes manifests for the ML service
|   |   |-- iris-api.yaml           # Namespace, ServiceAccount, Deployment, Service
|   |   `-- ingress-gateway.yaml    # Istio Gateway + VirtualService
|   `-- deploy.sh                   # render signed image digest and deploy app
|-- network-policies/               # Cilium microsegmentation policies
|   `-- default-deny-and-allow.yaml # Cilium default-deny and allow policies
|-- istio/                          # Mesh mTLS and service authorization
|   |-- peer-authentication.yaml    # Mesh-wide STRICT mTLS
|   |-- authz-policy.yaml           # Istio service authorization policy
|   `-- destination-rule.yaml       # Mutual TLS destination rules
|-- spire/                          # Standalone SPIRE reference manifests
|   |-- server.yaml                 # SPIRE server configuration
|   `-- workload-attestor.yaml      # Kubernetes workload attestation
|-- secrets/                        # Vault-backed Kubernetes secret references
|   `-- vault-eso.yaml              # Vault and External Secrets references
|-- policies/                       # Admission-time security policy
|   `-- kyverno-zero-trust.yaml     # Kyverno admission controls
|-- falco-rules/                    # Runtime detection rules
|   `-- ml-platform.yaml            # Runtime detection rules for ML pods
|-- audit/                          # Audit policy and integrity verification
|   |-- audit-policy.yaml           # Kubernetes audit policy
|   |-- hash-chain.py               # Tamper-evident audit verifier
|   `-- long-term-storage/          # S3 Object Lock forwarding and verification
|       |-- audit-forwarder.yaml    # fluent-bit audit/falco -> S3 Object Lock
|       |-- deploy.sh               # render Terraform outputs into forwarder manifest
|       |-- commit-chain.sh         # commit a chain for a closed audit window
|       `-- verify.sh               # pull objects + verify existing hash chain
|-- benchmarks/                     # NFR-001/NFR-002 measurement scripts
|   |-- README.md                   # Benchmark usage notes
|   |-- performance/                # p95 latency measurement
|   |   |-- measure-p95.py          # Single endpoint p50/p95/max probe
|   |   `-- compare.sh              # Baseline vs mesh p95 overhead check
|   `-- cost/                       # Infrastructure cost comparison
|       `-- compare.sh              # Baseline vs zero-trust monthly cost check
`-- tests/                          # Acceptance and penetration checks
    `-- penetration.sh              # Penetration validation script
```

## Implemented Controls

| Requirement | Local implementation |
|---|---|
| Network microsegmentation | `network-policies/default-deny-and-allow.yaml` |
| Service mesh mTLS | `istio/peer-authentication.yaml`, `istio/destination-rule.yaml` |
| Service authorization | `istio/authz-policy.yaml` |
| Workload identity | `helm/spire-values.yaml`; standalone manifests in `spire/` |
| Vault-backed secrets | `secrets/vault-eso.yaml` |
| Admission controls | `policies/kyverno-zero-trust.yaml` |
| Runtime detection | `falco-rules/ml-platform.yaml` |
| Audit integrity | `audit/audit-policy.yaml`, `audit/hash-chain.py` |
| Penetration checks | `tests/penetration.sh` |
| Infrastructure provisioning | `terraform/` |
| Platform installation | `helm/install.sh` + per-component values |
| Long-term audit storage | `terraform/audit-storage.tf` + `audit/long-term-storage/` |
| ML application deployment | `app/` |
| Performance and cost benchmarks | `benchmarks/` |

## Components

### Network Microsegmentation

`network-policies/default-deny-and-allow.yaml` defines Cilium default-deny
ingress and egress policies for `team-a`, `team-b`, and `iris`.

The `iris-api-allow` policy only permits:

- ingress from Istio ingressgateway to `iris-api` on TCP `8080`
- egress to kube-dns on UDP `53`
- egress to Vault on TCP `8200`

This blocks cross-tenant movement unless an explicit allow policy is added.

### Istio mTLS and Authorization

`istio/peer-authentication.yaml` enables mesh-wide `STRICT` mTLS.

`istio/destination-rule.yaml` forces `ISTIO_MUTUAL` TLS for service traffic and
adds connection-pool and outlier-detection settings for `iris-api`.

`istio/authz-policy.yaml` creates a deny-by-default mesh authorization policy
for the `iris` namespace, then explicitly allows ingress traffic from the
Istio ingressgateway service account to `/predict` and `/health`.

### SPIFFE/SPIRE Identity

`helm/spire-values.yaml` installs SPIRE with trust domain
`ml-platform.local`.

`spire/server.yaml` also shows a standalone SPIRE server configuration with a
24-hour default X.509 SVID TTL.

`spire/workload-attestor.yaml` runs the SPIRE agent as a DaemonSet and uses the
Kubernetes workload attestor to bind identities to namespace, service account,
and pod-label selectors. It documents the expected `iris-api` SPIFFE identity:

```text
spiffe://ml-platform.local/ns/iris/sa/iris-api
```

### Vault and External Secrets Operator

`secrets/vault-eso.yaml` defines a `ClusterSecretStore` pointing ESO at Vault
and an `ExternalSecret` for `iris-api`.

The manifest stores references only. The actual secret value is expected at:

```text
kv/iris/api model_registry_token
```

### Kyverno Admission Policy

`policies/kyverno-zero-trust.yaml` enforces:

- signed image verification through Kyverno `verifyImages`
- image digest pinning with `@sha256`
- required `owner` and `tier` labels
- non-root containers
- `allowPrivilegeEscalation: false`
- no `hostNetwork`, `hostPID`, or `hostIPC`

### Falco Runtime Detection

`falco-rules/ml-platform.yaml` detects:

- shell execution inside ML pods
- file writes outside approved ML paths
- suspicious outbound network connections
- privileged container startup

These rules complement admission policy by detecting behavior that occurs after
a workload has already been admitted.

### Audit Integrity

`audit/audit-policy.yaml` captures security-relevant Kubernetes API activity,
including workload writes, policy changes, and secret reads.

`audit/hash-chain.py` builds or verifies a tamper-evident SHA-256 hash chain
over exported audit log files.

`audit/long-term-storage/audit-forwarder.yaml` sends EKS control-plane audit
logs from CloudWatch and Falco JSON logs from nodes to the S3 Object Lock
bucket. `commit-chain.sh` writes the chain for a closed audit window, and
`verify.sh` verifies downloaded objects against that existing chain.

### ML Application

`app/iris-api/app.py` is a minimal inference service with:

- `GET /health`
- `POST /predict`

`app/kubernetes/iris-api.yaml` deploys it as a non-root, read-only filesystem
workload using the `iris-api` ServiceAccount and the Vault-backed
`iris-api-secrets` reference. Replace the sample image digest with the signed
image produced by your release pipeline before applying it:

```text
ghcr.io/example/ml-platform/iris-api@sha256:<signed-image-digest>
```

`app/kubernetes/ingress-gateway.yaml` exposes `/health` and `/predict` through
Istio ingressgateway.

## Provisioning the Cluster

`terraform/` provisions a VPC, an EKS cluster with control-plane audit logs
enabled, and the tamper-evident S3 audit bucket. The bucket uses Object Lock
in COMPLIANCE mode and an IRSA role for the in-cluster log forwarder.

```bash
cd terraform
terraform init
terraform apply -var "audit_bucket_name=<globally-unique-name>"
```

Outputs include `cluster_name`, `audit_bucket`, and `audit_writer_role_arn`.

## Installing the Platform Components

`helm/install.sh` installs all seven dependencies (Cilium, Istio, SPIRE,
Vault, External Secrets Operator, Kyverno, Falco) using the values files in
`helm/`. Run after `aws eks update-kubeconfig` points kubectl at the cluster:

```bash
bash helm/install.sh
```

The Falco install side-loads `falco-rules/ml-platform.yaml` via `--set-file`,
so no separate rules step is required.

## Apply Order

Apply the in-repo manifests after the platform components are healthy.
First create the tenant namespaces that the policies, secrets, and mesh
manifests reference (without this step `kubectl apply` rejects the
namespaced resources):

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: iris
  labels: { istio-injection: enabled, owner: ml-platform, tier: ml }
---
apiVersion: v1
kind: Namespace
metadata: { name: team-a, labels: { owner: team-a } }
---
apiVersion: v1
kind: Namespace
metadata: { name: team-b, labels: { owner: team-b } }
EOF

kubectl apply -f istio/peer-authentication.yaml
kubectl apply -f istio/destination-rule.yaml
kubectl apply -f istio/authz-policy.yaml
kubectl apply -f network-policies/default-deny-and-allow.yaml
kubectl apply -f secrets/vault-eso.yaml
kubectl apply -f policies/kyverno-zero-trust.yaml
```

Render Terraform outputs into the audit forwarder before applying it:

```bash
export AUDIT_BUCKET=$(terraform -chdir=terraform output -raw audit_bucket)
export AUDIT_WRITER_ROLE_ARN=$(terraform -chdir=terraform output -raw audit_writer_role_arn)
export CLUSTER_NAME=$(terraform -chdir=terraform output -raw cluster_name)
export AWS_REGION=us-west-2
bash audit/long-term-storage/deploy.sh
```

Deploy the ML application with a signed image digest that matches the Kyverno
`verifyImages` policy:

```bash
export SIGNED_IMAGE_DIGEST=ghcr.io/example/ml-platform/iris-api@sha256:<signed-image-digest>
bash app/deploy.sh
```

On EKS, control-plane audit logging is enabled by `cluster_enabled_log_types`
in `terraform/eks.tf`. On self-managed clusters, wire `audit/audit-policy.yaml`
into the kube-apiserver audit-policy flags directly.

## Validation

Run the penetration checks:

```bash
bash tests/penetration.sh
```

The script expects the following attacks to be blocked or detected:

- read another tenant's secret
- deploy an unsigned image
- deploy a root container
- deploy a host-namespace pod
- spawn a shell in an ML pod and trigger a Falco alert
- reach a service across tenant namespaces
- find plaintext secrets in manifests

To verify exported audit logs, first build a chain:

```bash
python3 audit/hash-chain.py build --chain audit-chain.json /path/to/audit-logs/*
```

Then verify it:

```bash
python3 audit/hash-chain.py verify --chain audit-chain.json /path/to/audit-logs/*
```

To verify logs already shipped to the long-term S3 bucket:

```bash
export AUDIT_BUCKET=$(terraform -chdir=terraform output -raw audit_bucket)
export CHAIN_KEY=k8s-audit/chain.json
bash audit/long-term-storage/commit-chain.sh k8s-audit/
bash audit/long-term-storage/verify.sh k8s-audit/
```

`tests/penetration.sh` can also verify the audit chain when these variables are
set:

```bash
export AUDIT_LOG_DIR=/path/to/audit-logs
export AUDIT_CHAIN_FILE=audit-chain.json
bash tests/penetration.sh
```

## Benchmarks

Measure NFR-001 p95 latency overhead:

```bash
export BASELINE_URL=http://baseline.example.com/predict
export MESH_URL=http://iris-api.example.com/predict
bash benchmarks/performance/compare.sh
```

Measure NFR-002 monthly cost overhead:

```bash
export BASELINE_MONTHLY_USD=1000
export ZERO_TRUST_MONTHLY_USD=1125
bash benchmarks/cost/compare.sh
```

## Requirement Coverage

| ID | Status | Notes |
|---|---|---|
| FR-001 | Implemented | Cilium default-deny plus explicit `iris-api` allow policy |
| FR-002 | Implemented | Istio STRICT mTLS and SPIRE 24h SVID TTL |
| FR-003 | Implemented | Vault and ESO references only; no secret values in manifests |
| FR-004 | Implemented | Kyverno signed image, label, non-root, and host namespace gates |
| FR-005 | Implemented | Falco rules for shell, file modification, egress, and privilege events |
| FR-006 | Implemented | Kubernetes audit policy plus local hash-chain verifier |
| NFR-001 | Benchmark implemented | Run `benchmarks/performance/compare.sh` against deployed baseline and mesh endpoints |
| NFR-002 | Benchmark implemented | Run `benchmarks/cost/compare.sh` with baseline and zero-trust monthly costs |
| NFR-003 | Partially covered | Reusable namespace policy templates are present; no onboarding automation |

## Current Scope

This repository covers infrastructure provisioning, platform install,
application deployment, long-term audit storage, penetration tests, and
benchmark harnesses. It still does not include:

- real signed production image digests
- collected benchmark result files from a live cluster

The signed image digest is intentionally injected at deploy time through
`SIGNED_IMAGE_DIGEST`, because a real digest only exists after the image is
built, pushed, and signed by the release pipeline.

Benchmark result files are generated by the scripts in `benchmarks/` when they
run against a live baseline cluster and the zero-trust cluster. Static result
files are not committed because they would not prove the current deployment's
NFR-001 or NFR-002 status.
