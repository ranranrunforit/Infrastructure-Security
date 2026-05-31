# Security Operations Center for ML

This project defines a lightweight SOC operating model for an ML platform. It covers log collection, Sigma detections, alert routing, SOAR actions, threat-intel enrichment, incident playbooks, tabletop exercises, and a blameless postmortem template.

## Scope

The SOC is designed to detect and respond to:

- lateral movement from ML workloads
- privilege escalation in Kubernetes / ML namespaces
- data exfiltration from sensitive ML data workloads
- model extraction and theft
- adversarial query patterns causing inference degradation
- data poisoning in training pipelines

## Repository Layout

```
Security Operations Center for ML/
|-- README.md                       # Project overview and usage guide
|-- REQUIREMENTS.md                 # Project requirements
|-- siem/
|   |-- log-sources.yml             # SIEM log source definitions
|   `-- alert-routing.yml           # Paging, escalation, and notification routing
|-- sigma-rules/
|   |-- lateral-movement.yml        # Lateral movement detection rule
|   |-- privilege-escalation.yml    # Privilege escalation detection rule
|   |-- data-exfiltration.yml       # Sensitive data exfiltration detection rule
|   |-- model-extraction.yml        # Model theft and extraction detection rule
|   `-- adversarial-dos.yml         # Adversarial inference DoS detection rule
|-- soar/
|   `-- automated-response.yml      # Automated response action mappings
|-- threat-intel/
|   `-- feeds.yml                   # Threat intelligence feed configuration
|-- playbooks/
|   |-- model-theft.md              # Model theft incident response playbook
|   |-- data-poisoning.md           # Data poisoning incident response playbook
|   `-- adversarial-dos.md          # Adversarial DoS incident response playbook
|-- tabletop/
|   |-- q1-tabletop.md              # Quarterly tabletop exercise
|   `-- injection-scripts.sh        # Incident-signal injection script
`-- postmortem-template.md          # Blameless postmortem template
```

## SIEM

[siem/log-sources.yml](siem/log-sources.yml) defines the log sources that feed the SIEM:

- Kubernetes audit logs for RBAC changes, exec / attach activity, and secret access
- Falco runtime alerts for container behavior
- Vault audit logs for secret access and token activity
- model registry audit logs for artifact downloads and version changes
- service mesh access logs for workload-to-workload traffic

All sources normalize into ECS-style fields so the Sigma rules can use consistent names such as `user.name`, `kubernetes.namespace`, `source.spiffe_id`, `destination.service`, and `network.bytes_out`.

[siem/alert-routing.yml](siem/alert-routing.yml) defines 24/7 coverage, weekly primary / secondary rotation, escalation timing, critical / high severity paging, Slack notification channels, and silence limits requiring an incident or change ticket.

## Detection Rules

Detection rules are stored in [sigma-rules/](sigma-rules/) using Sigma-style YAML. They include both MITRE ATT&CK and MITRE ATLAS tags where relevant.

| Rule | Purpose | Severity |
|------|---------|----------|
| `lateral-movement.yml` | Detects ML workloads connecting to unauthorized services such as model registry, feature store, Vault, or secrets manager. | high |
| `privilege-escalation.yml` | Detects risky RBAC changes and suspicious exec / attach activity in ML namespaces. | high |
| `data-exfiltration.yml` | Detects large outbound transfers from workloads labeled with sensitive data classes. | critical |
| `model-extraction.yml` | Detects high-rate, high-diversity inference queries that suggest model extraction. | high |
| `adversarial-dos.yml` | Detects distributed, high-cost adversarial inference traffic causing latency and throughput degradation. | critical |

## SOAR

[soar/automated-response.yml](soar/automated-response.yml) maps known detections to automated response actions:

- block source IPs for confirmed bulk exfiltration
- rotate SPIFFE-bound workload secrets after lateral movement
- isolate pods attempting privilege escalation
- rate-limit tenants suspected of model extraction

Actions include approval thresholds, cooldowns, notifications, and an audit log path for the SOAR runner.

## Threat Intelligence

[threat-intel/feeds.yml](threat-intel/feeds.yml) configures threat-intel ingestion and alert enrichment:

- CISA KEV catalog
- CISA STIX / TAXII feed
- MITRE ATLAS technique data
- model-vendor advisory feeds
- commercial STIX / TAXII IOC feed

The feed configuration correlates indicators against source / destination IPs, file hashes, URLs, and CVE IDs, then enriches alerts with feed name, confidence, first seen, last seen, and associated actor metadata.

Required secrets are referenced by environment variable:

- `CISA_TAXII_API_KEY`
- `RF_API_TOKEN`

## Incident Playbooks

The [playbooks/](playbooks/) directory contains response procedures for ML-specific incidents:

- `model-theft.md`: triage high-volume diverse inference queries, rate-limit users, preserve logs, revoke keys, and consider model rotation.
- `data-poisoning.md`: halt promotion, roll back affected models, quarantine feeds, snapshot artifacts, investigate dataset changes, and retrain from clean data.
- `adversarial-dos.md`: tighten rate limits, block source IPs / ASNs, shed load to degraded-mode models, and investigate adversarial input patterns.

Each playbook includes trigger conditions, severity assessment, immediate response, investigation, remediation, and recovery steps.

## Tabletop Exercises

[tabletop/q1-tabletop.md](tabletop/q1-tabletop.md) defines a quarterly tabletop with three ML-specific scenarios:

- model theft
- data poisoning
- adversarial DoS

[tabletop/injection-scripts.sh](tabletop/injection-scripts.sh) provides simple incident-signal injections for those scenarios.

Usage:

```bash
./tabletop/injection-scripts.sh model-theft
./tabletop/injection-scripts.sh data-poisoning
./tabletop/injection-scripts.sh adversarial-dos
```

Optional environment variables:

- `NAMESPACE`
- `INFERENCE_URL`
- `VICTIM_TOKEN`

## Postmortems

[postmortem-template.md](postmortem-template.md) is a blameless, action-oriented postmortem template. It captures impact, timeline, root cause, ML-specific considerations, action items, and supporting data.

Use it after any declared incident or tabletop exercise that identifies material gaps.
