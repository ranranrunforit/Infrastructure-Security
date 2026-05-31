"""Column-level lineage from source columns to trained model inputs."""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class ColumnRef:
    dataset: str
    column: str


@dataclass
class LineageGraph:
    edges: dict[ColumnRef, set[ColumnRef]] = field(default_factory=dict)

    def add_derivation(self, source: ColumnRef, target: ColumnRef) -> None:
        self.edges.setdefault(target, set()).add(source)

    def upstream_sources(self, target: ColumnRef) -> set[ColumnRef]:
        sources = set(self.edges.get(target, set()))
        for source in list(sources):
            sources.update(self.upstream_sources(source))
        return sources

    def model_lineage(self, model_name: str, feature_columns: list[ColumnRef]) -> dict[str, list[str]]:
        return {
            f"{model_name}.{feature.column}": sorted(
                f"{source.dataset}.{source.column}" for source in self.upstream_sources(feature)
            )
            for feature in feature_columns
        }
