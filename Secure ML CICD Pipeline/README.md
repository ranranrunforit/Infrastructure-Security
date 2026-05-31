# Secure ML CI/CD Pipeline

This repository contains a secure CI/CD reference implementation for ML workloads. It focuses on verifying the software supply chain before anything is promoted or admitted into the cluster.

The implemented controls cover:

- Signed commits and protected `main` branch configuration
- GitHub Actions CI for build, scan, signing, SBOM, provenance, and audit attestation
- Trivy and Grype vulnerability gates that fail on `HIGH` or `CRITICAL`
- CycloneDX SBOM attached to the built image
- Cosign keyless image signatures and signed provenance
- Kyverno admission policies for image signature, SBOM attestation, and SLSA provenance
- Model artifact signing in an OCI registry and verification at serving startup
- GitOps deployment through ArgoCD app-of-apps
- Bypass tests for the admission and model verification gates

## Repository Layout

```text
Secure ML CICD Pipeline/
|-- README.md                       # Project overview and usage guide
|-- REQUIREMENTS.md                 # Project requirements
|-- .github/
|   |-- branch-protection.md        # Required branch protection controls
|   `-- workflows/
|       `-- secure-pipeline.yml     # Secure build, scan, signing, and attestation workflow
|-- argocd/
|   |-- app-of-apps.yaml            # ArgoCD app-of-apps entry point
|   `-- apps/
|       |-- kyverno-policies.yaml   # GitOps app for Kyverno policies
|       `-- ml-serving.yaml         # GitOps app for ML serving manifests
|-- ci-examples/
|   `-- secure-pipeline.yml         # Reusable copy of the secure pipeline
|-- kyverno/
|   |-- verify-image-signature.yaml # Admission policy for signed images
|   |-- verify-sbom-attestation.yaml # Admission policy for SBOM attestations
|   `-- verify-slsa-provenance.yaml # Admission policy for SLSA provenance
|-- model-signing/
|   |-- sign_model.sh               # Model artifact signing script
|   `-- verify_model.sh             # Model artifact verification script
`-- tests/
    `-- bypass_attempts.sh          # Admission and model gate bypass tests
```

## CI Pipeline

The active workflow is `.github/workflows/secure-pipeline.yml`. The copy in `ci-examples/secure-pipeline.yml` mirrors the same pipeline for reuse.

The workflow runs on pushes and pull requests to `main`.

Pipeline gates:

1. Verifies signed commits.
2. Runs CodeQL.
3. Runs TruffleHog verified secret scanning.
4. Builds and pushes the image to `ghcr.io/${{ github.repository }}/app:${{ github.sha }}`.
5. Generates a CycloneDX SBOM.
6. Runs Trivy and fails on `HIGH` or `CRITICAL`.
7. Runs Grype and fails on `HIGH` or `CRITICAL`.
8. Signs the image with cosign keyless signing.
9. Attaches the CycloneDX SBOM as a cosign attestation.
10. Writes an immutable CI audit attestation to the image.
11. Publishes signed build provenance with `actions/attest-build-provenance`.

Required workflow permissions are already declared in the workflow:

- `contents: read`
- `packages: write`
- `id-token: write`
- `attestations: write`
- `security-events: write`

## Source Protection

Branch protection requirements are documented in `.github/branch-protection.md`.

Apply these controls to `main`:

- Require pull requests before merge
- Require at least one approval
- Require signed commits
- Require the `secure-pipeline / build` status check
- Require branches to be up to date
- Restrict direct pushes
- Disallow bypassing branch protection
- Require linear history

This keeps promotion git-only: changes are merged to Git, then ArgoCD reconciles from Git.

## Admission Policies

Kyverno policies live in `kyverno/`.

`verify-image-signature.yaml` requires every Pod image to have a cosign keyless signature from the trusted GitHub Actions workflow identity:

```text
https://github.com/*/.github/workflows/secure-pipeline.yml@*
```

`verify-sbom-attestation.yaml` requires a CycloneDX SBOM attestation.

`verify-slsa-provenance.yaml` requires SLSA provenance and checks that the provenance came from `refs/heads/main`.

All three policies use `validationFailureAction: Enforce`, so non-compliant Pods should be rejected at admission.

## GitOps Deployment

ArgoCD configuration lives in `argocd/`.

`argocd/app-of-apps.yaml` points ArgoCD at `argocd/apps`.

The child apps are:

- `argocd/apps/kyverno-policies.yaml`: syncs the Kyverno policies from `kyverno/`
- `argocd/apps/ml-serving.yaml`: points to the expected ML serving manifests at `deploy/ml-serving`

Before applying these manifests in a real repository, replace the placeholder repo URL:

```text
https://github.com/ORG/secure-ml-cicd
```

with the actual Git repository URL.

## Model Artifact Signing

Model signing scripts live in `model-signing/`.

`sign_model.sh` pushes a model artifact to an OCI registry, resolves the immutable digest, signs that digest with cosign, writes a local blob signature, and attaches an audit attestation.

Usage:

```bash
model-signing/sign_model.sh model.bin ghcr.io/ORG/secure-ml-cicd/model:VERSION
```

The script prints the immutable registry subject after signing. Use that digest reference at serving time.

`verify_model.sh` is intended to run before the serving process loads the model. It verifies both:

- the registry artifact signature
- the local model blob signature and certificate identity

Usage:

```bash
export COSIGN_IDENTITY="https://github.com/ORG/REPO/.github/workflows/train.yml@refs/heads/main"
model-signing/verify_model.sh model.bin ghcr.io/ORG/secure-ml-cicd/model:VERSION@sha256:DIGEST
```

If verification fails, the script exits non-zero and serving should refuse to load the model.

## Audit Records

The image CI pipeline writes a cosign attestation with type:

```text
secureml.cicd.audit/v1
```

The model signing script writes a cosign attestation with type:

```text
secureml.model.audit/v1
```

These audit records are attached to immutable registry subjects so they can be verified later with cosign.

## Bypass Tests

`tests/bypass_attempts.sh` attempts to bypass the expected gates.

It checks that the cluster rejects:

- an unsigned image
- a signed image without the required SBOM/SLSA attestations
- an image from the wrong workflow identity
- an unsigned model blob

Run it against a cluster with Kyverno and these policies installed:

```bash
tests/bypass_attempts.sh
```

The test passes only when every bypass attempt is rejected.

## Required Tools

For local or cluster validation, install the tools used by these artifacts:

- `kubectl`
- `cosign`
- `oras`
- `gh`, if applying branch protection through the GitHub CLI
- Kyverno installed in the target cluster
- ArgoCD installed in the target cluster

GitHub Actions installs the CI-specific action dependencies during workflow execution.

## Notes

- The CI image name is `ghcr.io/${{ github.repository }}/app`.
- The trust identity in Kyverno is tied to `.github/workflows/secure-pipeline.yml`.
- The ArgoCD repo URL is a placeholder and must be changed before deployment.
- `argocd/apps/ml-serving.yaml` expects serving manifests under `deploy/ml-serving`; add those manifests in the application repository when wiring the real serving workload.
