"""Label-flip data poisoning attack (for testing data-validation defenses)."""
from __future__ import annotations

import numpy as np


def label_flip(y: np.ndarray, fraction: float = 0.1,
               source: int | None = None, target: int | None = None,
               seed: int = 0) -> np.ndarray:
    """Flip `fraction` of labels. If source/target given, flip source->target only."""
    rng = np.random.default_rng(seed)
    y_poisoned = y.copy()
    if source is not None and target is not None:
        idx = np.where(y == source)[0]
        chosen = rng.choice(idx, size=int(len(idx) * fraction), replace=False)
        y_poisoned[chosen] = target
    else:
        n = int(len(y) * fraction)
        chosen = rng.choice(len(y), size=n, replace=False)
        classes = np.unique(y)
        y_poisoned[chosen] = rng.choice(classes, size=n)
    return y_poisoned
