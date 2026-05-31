# Q1 2026 Tabletop — ML SOC

## Format
- 2h session, 8 participants (SRE, ML platform, security, product on-call)
- Facilitator presents scenario; participants respond as they would in real incident
- Document gaps; convert to action items

## Scenario A — Model Theft (45 min)
A junior data scientist's API key has been used in the past 6 hours to query
the production fraud-detection model at 50K queries/hour from an IP in
Belarus. The user is on PTO in Hawaii.

Questions:
- What's the first thing you do?
- Who needs to know in the first hour?
- How do you know if the model was actually extracted?
- What do you tell legal?
- What changes after the incident?

## Scenario B — Data Poisoning (45 min)
The nightly model retrain produced a model with 30% accuracy regression on
the protected demographic A. The training data ingestion was modified 2 weeks
ago to include a new vendor feed.

Questions:
- Roll back the retrained model? (yes/no — why)
- How do you quarantine the new vendor feed?
- How do you reconstruct what happened?
- When do you notify the vendor?

## Scenario C — Adversarial DoS (30 min)
The customer-facing recommendation model's p99 latency has spiked to 12× baseline
over the last 20 min. GPU utilization is pinned at 100% but throughput dropped
40%. Traffic is coming from ~200 source IPs across a single ASN, each sending
heavily-perturbed inputs at the per-tenant rate-limit ceiling.

Questions:
- What's the first thing you do — rate-limit, IP-block, or degrade the model?
- How do you tell adversarial inputs from organic traffic spike?
- When do you fail over to the degraded-mode model? Who signs off?
- How do you stop the autoscaler from burning the budget while you investigate?

## Synthesis
- Top 3 gaps identified across scenarios
- Action items with owner + due date
- Schedule Q2 tabletop with new scenarios
