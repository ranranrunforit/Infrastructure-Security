# Playbook — Data Poisoning

## Trigger
- Retrained model shows accuracy regression > 5% on holdout set, OR
- Per-slice fairness regression > 10% on protected demographic, OR
- Data validation pipeline flags distribution shift on an upstream feed.

## Severity assessment (first 15 min)
- Identify which dataset version and which upstream feeds the retrain consumed
- Identify which downstream models were trained on the same dataset
- Determine blast radius: production-serving vs. shadow vs. experimental
- Check if affected models drive customer-facing decisions (loan, fraud, content)

## Immediate response (15-60 min)
1. **Halt promotion** of the affected model to production (freeze deploy)
2. **Roll back** any already-deployed model to last known-good checkpoint
3. **Quarantine** the suspected upstream feed at the ingestion layer
4. **Snapshot** the poisoned dataset + retrain artifacts for forensics

## Investigation (1-24h)
- Diff the suspect dataset against the last clean snapshot (row count, label
  distribution, per-feature distributions)
- Identify the time window the poisoned data entered the pipeline
- Cross-check vendor feed authentication logs in that window
- Determine whether the poisoning is: targeted (backdoor trigger), untargeted
  (label flipping), or availability (noise injection)

## Remediation
- Retrain from last clean snapshot with the suspect feed excluded
- Validate retrained model on a curated adversarial test set before re-deploy
- If a backdoor is suspected: run neural-cleanse / trigger-detection sweep
- Notify the vendor in writing if their feed was the entry point

## Recovery
- Re-enable the upstream feed only after vendor confirms integrity controls
- Add data-integrity checks (schema, distribution, anomaly detection) at
  ingestion for the affected pipeline
- File incident ticket; blameless postmortem within 1 week

## Companion
[engineer-solutions/mod-108 ex-09 POSTMORTEM_TEMPLATE.md](https://github.com/ai-infra-curriculum/ai-infra-engineer-solutions/blob/main/modules/mod-108-monitoring-observability/exercise-09-incident-response-gameday/POSTMORTEM_TEMPLATE.md)
