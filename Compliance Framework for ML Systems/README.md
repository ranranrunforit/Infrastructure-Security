# Project 2 Compliance Framework

Implements the required compliance capabilities for ML systems:

- Data inventory and `data_class` labels for `pii`, `phi`, `confidential`, and `public`
- GDPR subject DELETE, EXPORT, and EXPLAIN API
- Tamper-evident, queryable audit log with retention filtering
- Column-level lineage from source data to trained model features
- Bias and fairness review gate before Production promotion
- Quarterly GDPR, HIPAA, and SOC 2 report generation

## Layout

```
project-2-compliance/
+-- audit/             # tamper-evident audit hash chain
+-- data_inventory/    # classification scanner + Kyverno policy
+-- fairness/          # Production promotion fairness gate
+-- gdpr/              # subject rights API
+-- lineage/           # column-level lineage graph
+-- quarterly_report/  # quarterly compliance reports
```
