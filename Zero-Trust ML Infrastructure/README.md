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
.
|-- ARCHITECTURE.md
|-- REQUIREMENTS.md
|-- README.md
|-- network-policies/
|   `-- default-deny-and-allow.yaml
|-- istio/
|   |-- peer-authentication.yaml
|   |-- authz-policy.yaml
|   `-- destination-rule.yaml
|-- spire/
|   |-- server.yaml
|   `-- workload-attestor.yaml
|-- secrets/
|   `-- vault-eso.yaml
|-- policies/
|   `-- kyverno-zero-trust.yaml
|-- falco-rules/
|   `-- ml-platform.yaml
|-- audit/
|   |-- audit-policy.yaml
|   `-- hash-chain.py
`-- tests/
    `-- penetration.sh
```

## Implemented Controls

| Requirement | Local implementation |
|---|---|
| Network microsegmentation | `network-policies/default-deny-and-allow.yaml` |
| Service mesh mTLS | `istio/peer-authentication.yaml`, `istio/destination-rule.yaml` |
| Service authorization | `istio/authz-policy.yaml` |
| Workload identity | `spire/server.yaml`, `spire/workload-attestor.yaml` |
| Vault-backed secrets | `secrets/vault-eso.yaml` |
| Admission controls | `policies/kyverno-zero-trust.yaml` |
| Runtime detection | `falco-rules/ml-platform.yaml` |
| Audit integrity | `audit/audit-policy.yaml`, `audit/hash-chain.py` |
| Penetration checks | `tests/penetration.sh` |

## Components

### Network Microsegmentation

`network-policies/default-deny-and-allow.yaml` defines Cilium default-deny
ingress and egress policies for `team-a`, `team-b`, and `iris`.

The `iris-api-allow` policy only permits:

- ingress from the `ingress-nginx` namespace to `iris-api` on TCP `8080`
- egress to kube-dns on UDP `53`
- egress to Vault on TCP `8200`

This blocks cross-tenant movement unless an explicit allow policy is added.

### Istio mTLS and Authorization

`istio/peer-authentication.yaml` enables mesh-wide `STRICT` mTLS.

`istio/destination-rule.yaml` forces `ISTIO_MUTUAL` TLS for service traffic and
adds connection-pool and outlier-detection settings for `iris-api`.

`istio/authz-policy.yaml` creates a deny-by-default mesh authorization policy
for the `iris` namespace, then explicitly allows ingress traffic from the
`ingress-nginx` service account to `/predict` and `/health`.

### SPIFFE/SPIRE Identity

`spire/server.yaml` configures the SPIRE server with trust domain
`ml-platform.local` and a 24-hour default X.509 SVID TTL.

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

## Expected Cluster Prerequisites

Before applying these manifests, the cluster should already have:

- Kubernetes with namespaces such as `iris`, `team-a`, and `team-b`
- Cilium with `CiliumNetworkPolicy` CRDs installed
- Istio installed with sidecar injection enabled for protected namespaces
- Kyverno installed
- Vault reachable at `https://vault.vault.svc:8200`
- External Secrets Operator installed
- Falco installed and configured to load `falco-rules/ml-platform.yaml`
- `kubectl`, `rg`, and `python3` available where validation scripts run

This folder does not include full cluster provisioning, Helm installation, or
Terraform infrastructure.

## Apply Order

Apply the controls after the platform dependencies are installed:

```bash
kubectl apply -f spire/server.yaml
kubectl apply -f spire/workload-attestor.yaml
kubectl apply -f istio/peer-authentication.yaml
kubectl apply -f istio/destination-rule.yaml
kubectl apply -f istio/authz-policy.yaml
kubectl apply -f network-policies/default-deny-and-allow.yaml
kubectl apply -f secrets/vault-eso.yaml
kubectl apply -f policies/kyverno-zero-trust.yaml
```

Load `falco-rules/ml-platform.yaml` through the Falco deployment method used by
the cluster. Configure the Kubernetes API server with `audit/audit-policy.yaml`
as its audit policy.

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

`tests/penetration.sh` can also verify the audit chain when these variables are
set:

```bash
export AUDIT_LOG_DIR=/path/to/audit-logs
export AUDIT_CHAIN_FILE=audit-chain.json
bash tests/penetration.sh
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
| NFR-001 | Not measured here | Requires deployed-cluster latency testing |
| NFR-002 | Not measured here | Requires deployed-cluster cost comparison |
| NFR-003 | Partially covered | Reusable namespace policy templates are present; no onboarding automation |

## Current Scope

This repository is a security-control implementation, not a full production
platform installer. It does not include:

- `terraform/` infrastructure provisioning
- `helm/` charts for installing Cilium, Istio, SPIRE, Vault, ESO, Kyverno, or Falco
- a complete ML application deployment
- performance and cost benchmark results
- long-term audit log storage configuration

