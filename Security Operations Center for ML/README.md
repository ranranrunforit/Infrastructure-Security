# Project 5 Security Operations Center



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

