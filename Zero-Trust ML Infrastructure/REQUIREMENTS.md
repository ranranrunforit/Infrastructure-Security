# Project 1: Zero-Trust ML Infrastructure


**Prerequisites**: Senior infra engineer + Kubernetes + networking fundamentals

## Goal

Build a zero-trust ML platform where every request — pod-to-pod, user-to-service, service-to-cloud — is authenticated + authorized at every hop. No implicit trust.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ External user/service                                │
│   └─ OIDC → Envoy ingress → mTLS into mesh          │
│       └─ Istio sidecar verifies SPIFFE cert         │
│           └─ pod-to-pod mTLS (Linkerd / Istio)     │
│               └─ NetworkPolicy default-deny         │
│                   └─ OPA/Gatekeeper admission      │
│                       └─ Vault for secrets via ESO │
│                           └─ Falco runtime security│
└─────────────────────────────────────────────────────┘
```

## Required components

1. **Microsegmentation**: Cilium NetworkPolicies; default-deny + explicit allow
2. **Service mesh**: Istio or Linkerd with mTLS
3. **Identity**: SPIFFE/SPIRE per-workload identity
4. **Secrets**: Vault + External Secrets Operator
5. **Runtime security**: Falco rules for anomaly detection
6. **Admission**: OPA/Gatekeeper or Kyverno for pre-deploy policies
7. **Audit**: K8s audit log + tamper-evident chain

## Deliverables

- `terraform/` — full infra (VPC + EKS + Vault + observability)
- `helm/` — service mesh + ESO + Falco install
- `policies/` — OPA + Gatekeeper bundle
- `falco-rules/` — runtime rules
- `tests/` — penetration scenarios (must all fail to penetrate)
- `RUNBOOK.md` — operations playbook

## Acceptance

- All 7 components installed + integrated
- Penetration tests: attempt to (1) read another tenant's secret, (2) bypass NetworkPolicy, (3) spawn unsigned image, (4) escalate to root — all blocked + audit-logged
- Audit trail integrity verifiable
- Detailed `ARCHITECTURE.md`

## Requirements — Zero-Trust ML Infrastructure

### FR-001: Network microsegmentation
Default-deny ingress + egress per namespace. Explicit allow for known traffic
patterns only. Verified by: pod in team-A cannot reach service in team-B without
a NetworkPolicy.

### FR-002: mTLS between services
All pod-to-pod traffic uses mTLS via SPIFFE identity. Certificates auto-rotate
every 24h. Verified by: capturing traffic + observing encrypted handshakes.

### FR-003: Vault-backed secrets
No plaintext secrets in any manifest or ConfigMap. All secrets flow Vault →
ESO → Kubernetes Secret. Verified by: scan all manifests for plaintext;
expect zero hits.

### FR-004: Admission policies
Kyverno/OPA gates: signed images only, required labels, no root containers,
no host namespaces. Verified by: attempt to deploy violating Pods; all rejected.

### FR-005: Runtime detection
Falco rules detect + alert on: shell in container, file modifications outside
allowed paths, suspicious network connections. Verified by: trigger each rule;
alert fires within 30s.

### FR-006: Audit trail integrity
K8s audit log + service-mesh access logs in tamper-evident store. Verified by:
hash chain validates over 30-day window.

### NFR-001: Performance overhead
mTLS + service mesh: < 5ms p95 added latency per hop.

### NFR-002: Cost
< 15% additional infrastructure cost vs baseline cluster.

### NFR-003: Operability
Onboarding a new team takes < 1 hour with templates.
