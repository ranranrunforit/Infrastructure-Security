"""Require bias and fairness review before Production promotion."""
from __future__ import annotations

from dataclasses import dataclass

from audit.log import AuditLog


@dataclass(frozen=True)
class FairnessReview:
    model_version: str
    reviewer: str
    metrics: dict[str, float]
    approved: bool
    notes: str


class ProductionPromotionGate:
    def __init__(self, audit_log: AuditLog) -> None:
        self.audit_log = audit_log
        self.reviews: dict[str, FairnessReview] = {}

    def record_review(self, review: FairnessReview) -> None:
        self.reviews[review.model_version] = review
        self.audit_log.append(
            "model_promotion",
            review.reviewer,
            review.model_version,
            "fairness_review",
            {"approved": review.approved, "metrics": review.metrics, "notes": review.notes},
        )

    def promote_to_production(self, model_version: str, actor: str) -> dict[str, str]:
        review = self.reviews.get(model_version)
        if not review or not review.approved:
            raise PermissionError("Production promotion requires an approved bias and fairness review")
        self.audit_log.append("model_promotion", actor, model_version, "promote_production", {})
        return {"model_version": model_version, "environment": "Production", "status": "promoted"}
