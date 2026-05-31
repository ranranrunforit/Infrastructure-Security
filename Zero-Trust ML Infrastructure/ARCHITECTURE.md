# Architecture - Zero-Trust ML Infrastructure

## Layer Diagram

```text
L7  Application
    iris-api ML service, ServiceAccount identity, signed image, non-root pod

L6  Service Mesh
    Istio ingress, STRICT mTLS, AuthorizationPolicy, DestinationRule

L5  Workload Identity
    SPIFFE/SPIRE trust domain ml-platform.local, 24h X.509 SVID rotation

L4  Network Boundary
    Cilium default-deny ingress and egress, explicit DNS/Vault/ingress allows

L3  Admission
    Kyverno signed image verification, labels, non-root, no host namespaces

L2  Secrets
    Vault -> External Secrets Operator -> Kubernetes Secret references

L1  Runtime Detection
    Falco modern eBPF rules for shell, disallowed writes, egress, privilege

L0  Immutable Audit
    EKS audit logs + Falco JSON -> S3 Object Lock COMPLIANCE + hash chain
```

## Request Flow

```text
client
  -> Istio ingressgateway
  -> AuthorizationPolicy checks ingressgateway SPIFFE principal
  -> iris-api Service
  -> iris-api Pod with STRICT mTLS sidecar
  -> Vault-backed Kubernetes Secret reference
  -> audit and Falco events forwarded to immutable S3
```

## Control Mapping

| Layer | Files |
|---|---|
| Infrastructure | `terraform/` |
| Platform install | `helm/` |
| Application | `app/` |
| Mesh | `istio/` |
| Identity | `helm/spire-values.yaml`, `spire/` standalone manifests |
| Network policy | `network-policies/default-deny-and-allow.yaml` |
| Secrets | `secrets/vault-eso.yaml` |
| Admission | `policies/kyverno-zero-trust.yaml` |
| Runtime | `falco-rules/ml-platform.yaml` |
| Audit | `audit/` |
| Validation | `tests/`, `benchmarks/` |

## Notes

- The Istio trust domain and SPIRE trust domain are both `ml-platform.local`.
- The application ingress path uses Istio ingressgateway, not nginx ingress.
- EKS control-plane audit logs are read from CloudWatch and copied to S3.
- Falco node logs are tailed by a DaemonSet and copied to the same S3 bucket.
- S3 Object Lock prevents overwrite/delete during the retention window; the
  hash chain detects unexpected content changes across the retained objects.
