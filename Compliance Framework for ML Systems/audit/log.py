"""Tamper-evident audit log for compliance-relevant events."""
from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import UTC, datetime, timedelta
from hashlib import sha256
import json
from pathlib import Path
from typing import Any


SECURITY_EVENTS = {"auth", "secret_access", "model_promotion", "data_access"}


@dataclass(frozen=True)
class AuditEntry:
    sequence: int
    timestamp: str
    event_type: str
    actor: str
    resource: str
    action: str
    details: dict[str, Any]
    previous_hash: str
    entry_hash: str


class AuditLog:
    def __init__(self, path: str | Path, retention_days: int = 2555) -> None:
        self.path = Path(path)
        self.retention_days = retention_days
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.touch(exist_ok=True)

    def append(
        self,
        event_type: str,
        actor: str,
        resource: str,
        action: str,
        details: dict[str, Any] | None = None,
    ) -> AuditEntry:
        if event_type not in SECURITY_EVENTS:
            raise ValueError(f"event_type must be one of {sorted(SECURITY_EVENTS)}")
        current_entries = self.entries()
        previous = current_entries[-1].entry_hash if current_entries else "GENESIS"
        sequence = len(current_entries) + 1
        payload = {
            "sequence": sequence,
            "timestamp": datetime.now(UTC).isoformat(),
            "event_type": event_type,
            "actor": actor,
            "resource": resource,
            "action": action,
            "details": details or {},
            "previous_hash": previous,
        }
        payload["entry_hash"] = self._hash(payload)
        entry = AuditEntry(**payload)
        with self.path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(asdict(entry), sort_keys=True) + "\n")
        return entry

    def entries(self) -> list[AuditEntry]:
        with self.path.open(encoding="utf-8") as handle:
            return [AuditEntry(**json.loads(line)) for line in handle if line.strip()]

    def query(self, event_type: str | None = None, resource: str | None = None) -> list[AuditEntry]:
        results = self.entries()
        if event_type:
            results = [entry for entry in results if entry.event_type == event_type]
        if resource:
            results = [entry for entry in results if entry.resource == resource]
        return results

    def verify(self) -> bool:
        previous = "GENESIS"
        for expected_sequence, entry in enumerate(self.entries(), start=1):
            payload = asdict(entry)
            entry_hash = payload.pop("entry_hash")
            if entry.sequence != expected_sequence or entry.previous_hash != previous:
                return False
            if self._hash(payload) != entry_hash:
                return False
            previous = entry_hash
        return True

    def retained_entries(self) -> list[AuditEntry]:
        cutoff = datetime.now(UTC) - timedelta(days=self.retention_days)
        return [entry for entry in self.entries() if datetime.fromisoformat(entry.timestamp) >= cutoff]

    @staticmethod
    def _hash(payload: dict[str, Any]) -> str:
        encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
        return sha256(encoded).hexdigest()
