"""GDPR subject rights API: delete, export, and explain."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

try:
    from fastapi import FastAPI, HTTPException
except ImportError:
    FastAPI = None
    HTTPException = Exception

from audit.log import AuditLog


@dataclass
class ComplianceStore:
    warehouse: dict[str, list[dict[str, Any]]] = field(default_factory=dict)
    feature_store: dict[str, list[dict[str, Any]]] = field(default_factory=dict)
    training_data: dict[str, list[dict[str, Any]]] = field(default_factory=dict)
    model_artifacts: dict[str, dict[str, Any]] = field(default_factory=dict)
    predictions: dict[str, list[dict[str, Any]]] = field(default_factory=dict)

    def delete_subject(self, user_id: str) -> dict[str, int]:
        deleted = {
            "warehouse": len(self.warehouse.pop(user_id, [])),
            "feature_store": len(self.feature_store.pop(user_id, [])),
            "training_data": len(self.training_data.pop(user_id, [])),
            "model_artifacts": 0,
        }
        for artifact in self.model_artifacts.values():
            labels = artifact.get("contributed_labels", {})
            if user_id in labels:
                removed = labels.pop(user_id)
                deleted["model_artifacts"] += len(removed) if isinstance(removed, list) else 1
        return deleted

    def export_subject(self, user_id: str) -> dict[str, Any]:
        return {
            "user_id": user_id,
            "format": "application/json",
            "deadline": self._deadline(),
            "warehouse": self.warehouse.get(user_id, []),
            "feature_store": self.feature_store.get(user_id, []),
            "training_data": self.training_data.get(user_id, []),
            "predictions": self.predictions.get(user_id, []),
        }

    def explain_prediction(self, user_id: str, prediction_id: str) -> dict[str, Any]:
        for prediction in self.predictions.get(user_id, []):
            if prediction.get("prediction_id") == prediction_id:
                return {
                    "prediction_id": prediction_id,
                    "model_version": prediction["model_version"],
                    "input_features": prediction["input_features"],
                    "top_shap_contributions": prediction["top_shap_contributions"],
                    "decision_threshold": prediction["decision_threshold"],
                }
        raise KeyError(prediction_id)

    @staticmethod
    def _deadline() -> str:
        return (datetime.now(UTC) + timedelta(days=30)).date().isoformat()


store = ComplianceStore()
audit = AuditLog(Path(__file__).resolve().parents[1] / "audit" / "events.jsonl")

if FastAPI:
    app = FastAPI(title="ML Compliance GDPR API")

    @app.delete("/gdpr/subjects/{user_id}")
    def delete_subject(user_id: str) -> dict[str, Any]:
        deleted = store.delete_subject(user_id)
        audit.append("data_access", "gdpr-api", user_id, "delete", {"deleted": deleted})
        return {"user_id": user_id, "deadline_days": 30, "deleted": deleted}

    @app.get("/gdpr/subjects/{user_id}/export")
    def export_subject(user_id: str) -> dict[str, Any]:
        payload = store.export_subject(user_id)
        audit.append("data_access", "gdpr-api", user_id, "export", {"deadline": payload["deadline"]})
        return payload

    @app.get("/gdpr/subjects/{user_id}/predictions/{prediction_id}/explain")
    def explain_prediction(user_id: str, prediction_id: str) -> dict[str, Any]:
        try:
            payload = store.explain_prediction(user_id, prediction_id)
        except KeyError as exc:
            raise HTTPException(status_code=404, detail="prediction not found") from exc
        audit.append("data_access", "gdpr-api", prediction_id, "explain", {"user_id": user_id})
        return payload
