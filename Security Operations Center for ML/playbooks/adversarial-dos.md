# Playbook — Adversarial DoS

## Trigger
- Inference gateway p99 latency > 5× baseline for > 5 min, OR
- GPU utilization saturated with low throughput (compute-heavy adversarial
  inputs), OR
- Per-tenant request rate exceeds rate-limit threshold from multiple identities
  sharing common attack signatures.

## Severity assessment (first 5 min)
- Identify affected model + tenant(s)
- Check whether load is organic (correlated with a product event) or
  attack-driven (no upstream cause; clustered source IPs / ASNs)
- Pull a sample of inputs from the offending window — look for high-perturbation
  / out-of-distribution patterns indicative of adversarial examples

## Immediate response (5-15 min)
1. **Tighten per-tenant rate limits** on the offending tenant(s) at the API gateway
2. **Block** offending source IPs / ASNs at the edge (WAF)
3. **Shed load**: route to a degraded-mode model (smaller / cheaper) for the
   affected route
4. **Page** the model-platform on-call; notify product on-call of degraded SLA

## Investigation (15-60 min)
- Cross-reference attack signatures with threat-intel IOC feeds (CISA, vendor)
- Diff request inputs against known adversarial-example datasets
- Determine whether the attacker is probing for evasion (model-extraction-adjacent)
  or pure resource exhaustion
- Check whether autoscaling masked the attack by inflating cost (budget alarm)

## Remediation
- Keep rate limit + IP blocks in place until 1h clean
- If adversarial inputs are confirmed: deploy input-validation / preprocessing
  defense (image rescaling, prompt sanitization) on the affected route
- Add the attack signature to the input-filtering layer
- Review whether the autoscaling policy needs an attack-aware ceiling

## Recovery
- Restore normal rate limits incrementally with monitoring
- Restore primary model after capacity returns to baseline
- File incident ticket; blameless postmortem within 1 week

## Companion
[engineer-solutions/mod-108 ex-09 POSTMORTEM_TEMPLATE.md](https://github.com/ai-infra-curriculum/ai-infra-engineer-solutions/blob/main/modules/mod-108-monitoring-observability/exercise-09-incident-response-gameday/POSTMORTEM_TEMPLATE.md)
