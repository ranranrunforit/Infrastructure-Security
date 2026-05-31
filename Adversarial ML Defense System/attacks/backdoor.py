"""BadNets-style backdoor: stamp a small trigger patch and relabel to target class."""
from __future__ import annotations

import numpy as np
import torch


def stamp_trigger(x: torch.Tensor, patch_size: int = 3, value: float = 1.0) -> torch.Tensor:
    """Stamp a bright square in the bottom-right corner. x: (N,C,H,W) in [0,1]."""
    x = x.clone()
    x[..., -patch_size:, -patch_size:] = value
    return x


def poison_dataset(X: torch.Tensor, y: torch.Tensor,
                   target_label: int, fraction: float = 0.05,
                   patch_size: int = 3, seed: int = 0) -> tuple[torch.Tensor, torch.Tensor]:
    rng = np.random.default_rng(seed)
    n = int(len(X) * fraction)
    idx = rng.choice(len(X), size=n, replace=False)
    X_p, y_p = X.clone(), y.clone()
    X_p[idx] = stamp_trigger(X_p[idx], patch_size=patch_size)
    y_p[idx] = target_label
    return X_p, y_p


def attack_success_rate(model, X_clean: torch.Tensor, target_label: int,
                        patch_size: int = 3) -> float:
    """Fraction of triggered inputs that the model classifies as target_label."""
    model.train(False)
    X_trig = stamp_trigger(X_clean.cuda(), patch_size=patch_size)
    with torch.no_grad():
        preds = model(X_trig).argmax(-1)
    return float((preds == target_label).float().mean().item())
