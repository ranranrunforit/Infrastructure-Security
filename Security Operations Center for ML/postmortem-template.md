# Incident Postmortem - <title>

> Blameless. Action-oriented. People did the best they could with the
> information and tools available at the time. Focus on systems and process,
> not individuals.

## Summary
- **Incident ID**:
- **Date / time (UTC)**: detected -, mitigated -, resolved -
- **Severity**: SEV-?
- **Authors**:
- **Status**: draft / in-review / final

One paragraph: what happened, customer impact, how we resolved it.

## Impact
- Users / tenants affected:
- Models / services affected:
- Data affected (PII / PHI / model artifacts):
- Duration of degraded service:
- Financial / reputational impact (if quantifiable):

## Timeline (UTC)
| Time | Event | Source |
|------|-------|--------|
| HH:MM | First signal (alert / report) | |
| HH:MM | On-call paged | |
| HH:MM | Incident declared | |
| HH:MM | Mitigation deployed | |
| HH:MM | Service restored | |
| HH:MM | All-clear | |

## Root cause
Describe the underlying cause. Use the "five whys" or a causal chain. Avoid
naming individuals; name systems, processes, and decisions.

## What went well
-

## What went poorly
-

## Where we got lucky
-

## ML-specific considerations
- Was a model rolled back? Which version -> which version?
- Was training data quarantined? Which dataset version?
- Did we need to invalidate served predictions / cached embeddings?
- Was a watermark or model rotation triggered?
- Downstream models that consume affected data / model:

## Action items
Each item must have an owner, due date, and tracking link. Prefer durable
fixes (detection, automation, guardrails) over one-time cleanup.

| # | Action | Type (prevent / detect / mitigate / process) | Owner | Due | Ticket |
|---|--------|-----------------------------------------------|-------|-----|--------|
| 1 |        |                                               |       |     |        |
| 2 |        |                                               |       |     |        |

## Lessons learned
-

## Supporting data
- Alert links:
- Dashboards / graphs:
- Relevant logs / queries:
- Related incidents:

---

*This template is intentionally blameless. If a draft names an individual
as a cause, rewrite it to describe the system that allowed the action to
have impact.*
