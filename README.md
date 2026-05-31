# Infrastructure Security

Security-focused AI/ML infrastructure projects covering zero-trust platform controls, compliance automation, adversarial ML defense, secure ML CI/CD, and ML security operations.


## Overview

This repository contains five infrastructure security implementations for machine learning systems. Each subfolder includes its own README with implementation details, requirement coverage, and usage notes.

The projects are intentionally practical and control-focused. They emphasize Kubernetes security, service identity, policy enforcement, auditability, compliance workflows, adversarial ML defenses, supply-chain integrity, and security operations for ML platforms.

## Projects

| Project | Focus | Link |
|---|---|---|
| Zero-Trust ML Infrastructure | Kubernetes zero-trust controls for ML workloads | [Zero-Trust ML Infrastructure](/Zero-Trust%20ML%20Infrastructure) |
| Compliance Framework for ML Systems | GDPR, HIPAA, SOC 2, audit, lineage, and fairness controls | [Compliance Framework for ML Systems](/Compliance%20Framework%20for%20ML%20Systems) |
| Adversarial ML Defense System | Attack and defense utilities for adversarial ML threats | [Adversarial ML Defense System](/Adversarial%20ML%20Defense%20System) |
| Secure ML CI/CD Pipeline | Secure software supply chain and admission controls for ML workloads | [Secure ML CI/CD Pipeline](/Secure%20ML%20CICD%20Pipeline) |
| Security Operations Center for ML | ML-focused detection, response, threat intelligence, and incident operations | [Security Operations Center for ML](/Security%20Operations%20Center%20for%20ML) |

## Project Details

### 1. [Zero-Trust ML Infrastructure](/Zero-Trust%20ML%20Infrastructure) 

Builds a Kubernetes-based zero-trust reference implementation for ML workloads where service-to-service and tenant-to-platform interactions are authenticated, authorized, encrypted, and auditable.

**Technologies**

Kubernetes, Cilium NetworkPolicy, Istio mTLS and AuthorizationPolicy, SPIFFE/SPIRE workload identity, HashiCorp Vault, External Secrets Operator, Kyverno, Falco, Python and Bash validation utilities

**Deliverables**

- Cilium default-deny network policies with explicit ML service allow rules
- Mesh-wide strict mTLS and Istio service authorization policies
- SPIRE workload identity configuration with SPIFFE identities
- Vault-backed secret references through External Secrets Operator
- Kyverno admission controls for signed images, digest pinning, required labels, non-root containers, and host namespace restrictions
- Falco runtime detection rules for ML workloads
- Kubernetes audit policy and tamper-evident audit hash-chain verifier
- Penetration validation script for expected blocked or detected attacks


### 2. [Compliance Framework for ML Systems](/Compliance%20Framework%20for%20ML%20Systems)

Implements a lightweight compliance framework for ML systems, focused on data classification, GDPR subject rights, audit integrity, column-level lineage, fairness review gates, and quarterly compliance reporting.

**Technologies**

Python, pandas, FastAPI, Kyverno, JSONL audit logging, hash-chain integrity verification, Markdown report generation

**Deliverables**

- Data classification for `pii`, `phi`, `confidential`, and `public`
- Kyverno policy enforcing `data_class` labels on Kubernetes PV/PVC resources
- GDPR subject DELETE, EXPORT, and EXPLAIN API workflows
- Tamper-evident audit log with query, retention, and verification support
- Column-level lineage graph for model feature traceability
- Production promotion gate requiring approved fairness review
- Quarterly GDPR, HIPAA, and SOC 2 report generator


### 3. [Adversarial ML Defense System](/Adversarial%20ML%20Defense%20System)

Provides reusable Python modules for testing and defending ML models against evasion, poisoning, extraction, membership inference, backdoor, and NLP adversarial attacks.

**Technologies**

Python, PyTorch, NumPy, scikit-learn, FastAPI, Redis, Opacus, Adversarial Robustness Toolbox, Foolbox, TextAttack

**Deliverables**

- PGD evasion attack utilities, including native PyTorch, ART, and Foolbox variants
- Label-flip poisoning attack implementation
- Query-based model extraction and surrogate agreement scoring
- Membership inference threshold attack helpers
- Backdoor trigger stamping, poisoning, and attack-success measurement
- TextAttack recipe runner for NLP attacks
- PGD adversarial training utility
- IsolationForest input validation with FastAPI dependency support
- Redis-backed per-tenant query budget rate limiting
- Opacus DP-SGD wrapper and privacy budget reporting
- Neural Cleanse and activation clustering helpers for backdoor detection
- Trigger-set watermark embedding and verification
- Benchmark metrics for robustness, rejection rate, extraction agreement, membership inference accuracy, backdoor success, and watermark ownership


### 4. [Secure ML CI/CD Pipeline](/Secure%20ML%20CICD%20Pipeline)

Implements a secure CI/CD and GitOps reference pipeline for ML workloads, focused on supply-chain verification before artifacts are promoted or admitted into a Kubernetes cluster.

**Technologies**

GitHub Actions, CodeQL, TruffleHog, Trivy, Grype, CycloneDX SBOM, Cosign/Sigstore, SLSA provenance, Kyverno, ArgoCD, OCI registries and GHCR, Bash

**Deliverables**

- Signed-commit and protected-branch configuration guidance
- GitHub Actions workflow for build, scan, signing, SBOM, provenance, and audit attestation
- CodeQL and TruffleHog security gates
- Trivy and Grype vulnerability gates that fail on `HIGH` or `CRITICAL`
- CycloneDX SBOM generation and cosign attestation
- Cosign keyless image signatures and signed provenance
- Kyverno policies verifying image signatures, SBOM attestations, and SLSA provenance
- Model artifact signing and verification scripts
- ArgoCD app-of-apps GitOps deployment configuration
- Bypass tests for admission and model verification gates


### 5. [Security Operations Center for ML](/Security%20Operations%20Center%20for%20ML)

Defines a lightweight SOC operating model for ML platforms, covering log collection, Sigma detections, alert routing, automated response, threat intelligence, incident playbooks, tabletop exercises, and blameless postmortems.

**Technologies**

- Sigma detection rules
- SIEM log-source configuration with ECS-style fields
- Kubernetes audit logs
- Falco runtime alerts
- Vault audit logs
- Service mesh access logs
- MITRE ATT&CK and MITRE ATLAS mappings
- SOAR-style response configuration
- STIX/TAXII threat intelligence feeds
- Slack and paging-based alert routing
- Bash tabletop injection scripts

**Deliverables**

- SIEM log-source configuration for Kubernetes, Falco, Vault, model registry, and service mesh events
- Alert routing configuration for severity-based paging, escalation, Slack notifications, and silence limits
- ML-focused Sigma rules for lateral movement, privilege escalation, data exfiltration, model extraction, and adversarial DoS
- SOAR response mappings for source blocking, secret rotation, pod isolation, and tenant rate limiting
- Threat intelligence feed configuration and enrichment fields
- Incident playbooks for model theft, data poisoning, and adversarial DoS
- Quarterly tabletop exercise scenario and injection script
- Blameless postmortem template


## Repository Structure

```text
Infrastructure-Security/
|-- Adversarial ML Defense System/
|-- Compliance Framework for ML Systems/
|-- Secure ML CICD Pipeline/
|-- Security Operations Center for ML/
|-- Zero-Trust ML Infrastructure/
`-- README.md
```

## Cross-Project Coverage

| Security Area | Covered By |
|---|---|
| Network microsegmentation | [Zero-Trust ML Infrastructure](/Zero-Trust%20ML%20Infrastructure) |
| Service identity and mTLS | [Zero-Trust ML Infrastructure](/Zero-Trust%20ML%20Infrastructure) |
| Secrets management | [Zero-Trust ML Infrastructure](/Zero-Trust%20ML%20Infrastructure), [Security Operations Center for ML](/Security%20Operations%20Center%20for%20ML) |
| Admission control | [Zero-Trust ML Infrastructure](/Zero-Trust%20ML%20Infrastructure), [Secure ML CI/CD Pipeline](https://github.com/ranranrunforit/Infrastructure-Security/tree/main/Secure%20ML%20CICD%20Pipeline) |
| Audit integrity | [Zero-Trust ML Infrastructure](/Zero-Trust%20ML%20Infrastructure), [Compliance Framework for ML Systems](/Compliance%20Framework%20for%20ML%20Systems) |
| GDPR, HIPAA, and SOC 2 workflows | [Compliance Framework for ML Systems](/Compliance%20Framework%20for%20ML%20Systems) |
| Adversarial ML defense | [Adversarial ML Defense System](/Adversarial%20ML%20Defense%20System) |
| ML supply-chain security | [Secure ML CI/CD Pipeline](/Secure%20ML%20CICD%20Pipeline) |
| Detection and incident response | [Security Operations Center for ML](/Security%20Operations%20Center%20for%20ML) |

