# Project 5 Solution - Security Operations Center

Reference for [learning project 5](https://github.com/ai-infra-curriculum/ai-infra-security-learning/tree/main/projects/project-5-security-operations).

## Layout

```
project-5-security-operations/
|-- README.md
|-- siem/                    # log aggregation, alert routing, on-call
|   |-- log-sources.yml
|   `-- alert-routing.yml
|-- sigma-rules/             # detection rules in Sigma format (ATT&CK + ATLAS)
|   |-- lateral-movement.yml
|   |-- privilege-escalation.yml
|   |-- model-extraction.yml
|   |-- data-exfiltration.yml
|   `-- adversarial-dos.yml
|-- soar/                    # automated response (block IP, rotate secret, isolate pod)
|   `-- automated-response.yml
|-- threat-intel/            # STIX/TAXII feeds (CISA KEV, MITRE ATLAS, commercial)
|   `-- feeds.yml
|-- playbooks/               # incident response runbooks
|   |-- model-theft.md
|   |-- data-poisoning.md
|   `-- adversarial-dos.md
|-- tabletop/                # game day scenarios
|   |-- q1-tabletop.md
|   `-- injection-scripts.sh
`-- postmortem-template.md
```

Cross-references:
- [engineer-solutions/mod-108 ex-09 gameday](https://github.com/ai-infra-curriculum/ai-infra-engineer-solutions/tree/main/modules/mod-108-monitoring-observability/exercise-09-incident-response-gameday) - fault-injection scripts
- [engineer-solutions/mod-108 ex-07](https://github.com/ai-infra-curriculum/ai-infra-engineer-solutions/tree/main/modules/mod-108-monitoring-observability/exercise-07-alertmanager-routing) - alert routing
