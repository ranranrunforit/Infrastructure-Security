# Compliance Framework for ML Systems

This project implements a small compliance framework for machine learning
systems. It focuses on the requirements in `REQUIREMENTS.md`: data
classification, GDPR subject rights, audit integrity, column-level lineage,
fairness review before Production promotion, and quarterly compliance reports.

The implementation is intentionally lightweight and local-first. It provides
the core control logic and API surface without depending on an external
warehouse, feature store, model registry, or audit backend.

## Capabilities

- Classifies datasets as `pii`, `phi`, `confidential`, or `public`
- Enforces `data_class` labels on Kubernetes PV/PVC resources with Kyverno
- Supports GDPR subject DELETE, EXPORT, and EXPLAIN workflows
- Records security-relevant events in a tamper-evident hash chain
- Provides query and retention filtering for audit entries
- Tracks column-level lineage from source data to model features
- Blocks Production promotion unless a bias and fairness review is approved
- Generates quarterly GDPR, HIPAA, and SOC 2 report output

## Project Layout

```text
Compliance Framework for ML Systems/
|-- README.md                         # Project overview and usage guide
|-- REQUIREMENTS.md                   # Project requirements
|-- audit/
|   `-- log.py                       # tamper-evident audit log
|-- data_inventory/
|   |-- scan.py                      # dataframe PII/PHI classifier
|   `-- kyverno-data-class.yaml      # PV/PVC data_class enforcement
|-- fairness/
|   `-- promotion_gate.py            # Production fairness review gate
|-- gdpr/
|   `-- api.py                       # GDPR subject rights API
|-- lineage/
|   `-- graph.py                     # column-level lineage graph
`-- quarterly_report/
    `-- generate.py                  # quarterly compliance report generator
```

## Requirements

The Python modules use the standard library except for:

- `pandas`, used by `data_inventory/scan.py`
- `fastapi`, optional, used only when serving `gdpr/api.py` as an API
- an ASGI server such as `uvicorn`, optional, for running the FastAPI app

Example install:

```powershell
pip install pandas fastapi uvicorn
```

## Usage

### Data Classification

`data_inventory/scan.py` classifies a pandas DataFrame and returns a
`data_class` label plus detection hits.

```python
import pandas as pd

from data_inventory.scan import classify_dataframe

df = pd.DataFrame({"email": ["user@example.com"], "amount": [100]})
result = classify_dataframe(df)
print(result["labels"])
```

Expected label format:

```json
{"data_class": "pii"}
```

The Kyverno policy in `data_inventory/kyverno-data-class.yaml` enforces that
PersistentVolumes and PersistentVolumeClaims have one of these labels:

```text
pii | phi | confidential | public
```

### GDPR API

`gdpr/api.py` defines three subject-rights endpoints:

```text
DELETE /gdpr/subjects/{user_id}
GET    /gdpr/subjects/{user_id}/export
GET    /gdpr/subjects/{user_id}/predictions/{prediction_id}/explain
```

Run locally with FastAPI:

```powershell
uvicorn gdpr.api:app --reload
```

The in-memory `ComplianceStore` contains these logical stores:

- `warehouse`
- `feature_store`
- `training_data`
- `model_artifacts`
- `predictions`

DELETE removes a subject from warehouse, feature store, training data, and
model artifact contributed labels. EXPORT returns subject data and predictions
as JSON with a 30-day deadline. EXPLAIN returns model version, input features,
top SHAP contributions, and decision threshold for a prediction.

### Audit Log

`audit/log.py` records these security-relevant event types:

```text
auth | secret_access | model_promotion | data_access
```

Each entry stores its own hash and the previous entry hash. `verify()` checks
the chain, `query()` filters entries, and `retained_entries()` returns entries
inside the configured retention window.

Example:

```python
from audit.log import AuditLog

log = AuditLog("audit/events.jsonl")
log.append("data_access", "gdpr-api", "user-123", "export")
assert log.verify()
```

### Data Lineage

`lineage/graph.py` tracks column-level derivations. It can report upstream
source columns for model feature columns.

```python
from lineage.graph import ColumnRef, LineageGraph

graph = LineageGraph()
source = ColumnRef("raw_users", "email")
feature = ColumnRef("model_features", "email_domain")
graph.add_derivation(source, feature)

print(graph.model_lineage("fraud-model-v1", [feature]))
```

### Fairness Review Gate

`fairness/promotion_gate.py` requires an approved fairness review before a
model version can be promoted to Production. Review and promotion events are
written to the audit log.

```python
from audit.log import AuditLog
from fairness.promotion_gate import FairnessReview, ProductionPromotionGate

gate = ProductionPromotionGate(AuditLog("audit/events.jsonl"))
gate.record_review(
    FairnessReview(
        model_version="model-v1",
        reviewer="risk-team",
        metrics={"disparate_impact": 0.91},
        approved=True,
        notes="Passed review",
    )
)
gate.promote_to_production("model-v1", actor="release-manager")
```

### Quarterly Reports

`quarterly_report/generate.py` prints a quarterly Markdown report for GDPR,
HIPAA, and SOC 2. Each framework section includes controls implemented,
evidence of operation, status, and exceptions.

```powershell
python quarterly_report\generate.py
```

## Requirement Coverage

| Requirement | Implementation |
|---|---|
| FR-001 Data classification | `data_inventory/scan.py`, `data_inventory/kyverno-data-class.yaml` |
| FR-002 GDPR subject DELETE | `DELETE /gdpr/subjects/{user_id}` in `gdpr/api.py` |
| FR-003 GDPR subject EXPORT | `GET /gdpr/subjects/{user_id}/export` in `gdpr/api.py` |
| FR-004 GDPR subject EXPLAIN | `GET /gdpr/subjects/{user_id}/predictions/{prediction_id}/explain` in `gdpr/api.py` |
| FR-005 Audit log integrity | `audit/log.py` hash chain, query, and retention filtering |
| FR-006 Quarterly reports | `quarterly_report/generate.py` |
| NFR-001 Subject request SLA | DELETE response includes `deadline_days: 30`; EXPORT includes a 30-day `deadline` |

## Implementation Boundaries

- The GDPR API uses an in-memory store for the warehouse, feature store,
  training data, model artifacts, and predictions.
- The audit log is file-backed JSONL and tamper-evident, not tamper-proof.
- The EXPLAIN endpoint expects prediction records to already contain SHAP
  contribution data.
- The quarterly report generator prints Markdown to stdout; it does not create
  a signed PDF or submit reports automatically.
