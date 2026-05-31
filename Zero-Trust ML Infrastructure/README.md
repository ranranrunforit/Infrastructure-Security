# Project 1 Solution - Zero-Trust ML Infrastructure

Reference implementation for the zero-trust ML infrastructure project.

## Components

| Component | Implementation location |
|---|---|
| NetworkPolicy default-deny + allow | `network-policies/default-deny-and-allow.yaml` |
| mTLS via Istio | `istio/` |
| SPIFFE identity | `spire/` |
| Vault + ESO | `secrets/vault-eso.yaml` |
| Falco runtime rules | `falco-rules/ml-platform.yaml` |
| Kyverno admission policies | `policies/kyverno-zero-trust.yaml` |
| Audit policy + hash chain | `audit/` |

## Layout

```text
project-1-zero-trust/
|-- README.md
|-- ARCHITECTURE.md
|-- REQUIREMENTS.md
|-- SOLUTION.md
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

## Validation

Run the penetration checks against a cluster with Cilium, Istio, SPIRE,
Vault/ESO, Kyverno, and Falco installed:

```bash
bash tests/penetration.sh
```

To verify exported audit logs:

```bash
python3 audit/hash-chain.py verify --chain audit-chain.json /path/to/audit-logs/*
```
