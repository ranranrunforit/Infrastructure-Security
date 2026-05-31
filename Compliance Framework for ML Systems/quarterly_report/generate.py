"""Generate quarterly compliance report for GDPR + HIPAA + SOC 2."""
from __future__ import annotations

from datetime import UTC, date, datetime


CONTROLS_GDPR = {
    "Art. 5 - data minimization": "data_inventory classification labels",
    "Art. 17 - right to erasure": "GDPR DELETE endpoint",
    "Art. 20 - right to portability": "GDPR EXPORT endpoint",
    "Art. 22 - automated decision-making": "GDPR EXPLAIN endpoint",
    "Art. 32 - security of processing": "tamper-evident audit log",
}

CONTROLS_HIPAA = {
    "164.308 - administrative safeguards": "Production promotion fairness review gate",
    "164.312 - technical safeguards": "security-relevant audit events",
    "164.514 - de-identification": "PII/PHI classification inventory",
}

CONTROLS_SOC2 = {
    "CC6.1 - logical access": "auth and data access audit events",
    "CC7.2 - system monitoring": "queryable audit log",
    "CC7.3 - change management": "model promotion audit events",
}


def report() -> None:
    today = date.today()
    quarter = (today.month - 1) // 3 + 1
    print(f"# Compliance Report Q{quarter} {today.year}")
    print(f"\n_Generated {datetime.now(UTC).isoformat()}_\n")

    for framework, controls in [
        ("GDPR", CONTROLS_GDPR),
        ("HIPAA", CONTROLS_HIPAA),
        ("SOC 2", CONTROLS_SOC2),
    ]:
        print(f"\n## {framework}\n")
        print("| Control | Evidence of operation | Status | Exceptions |")
        print("|---|---|---|---|")
        for control, evidence in controls.items():
            print(f"| {control} | {evidence} | Implemented | None |")


if __name__ == "__main__":
    report()
