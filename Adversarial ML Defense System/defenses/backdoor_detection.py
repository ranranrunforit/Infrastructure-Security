"""Backdoor detection: Neural Cleanse trigger reverse-engineering + activation clustering."""
from __future__ import annotations

import numpy as np
import torch
from sklearn.cluster import KMeans


def neural_cleanse(model, target_class: int, input_shape: tuple,
                   steps: int = 500, lr: float = 0.1, lam: float = 1e-2) -> tuple[torch.Tensor, torch.Tensor]:
    """Reverse-engineer minimal (mask, pattern) that flips inputs to target_class.
    Small L1(mask) suggests a backdoor trigger for target_class."""
    model.train(False)
    mask = torch.zeros(input_shape, requires_grad=True, device="cuda")
    pattern = torch.zeros(input_shape, requires_grad=True, device="cuda")
    opt = torch.optim.Adam([mask, pattern], lr=lr)
    target = torch.tensor([target_class], device="cuda")

    for _ in range(steps):
        m = torch.sigmoid(mask)
        x = (1 - m) * torch.rand_like(m) + m * torch.sigmoid(pattern)
        out = model(x.unsqueeze(0))
        loss = torch.nn.functional.cross_entropy(out, target) + lam * m.abs().sum()
        opt.zero_grad(); loss.backward(); opt.step()
    return torch.sigmoid(mask).detach(), torch.sigmoid(pattern).detach()


def activation_clustering(activations: np.ndarray, n_clusters: int = 2) -> np.ndarray:
    """Cluster per-class penultimate activations; small cluster suggests poisoned samples."""
    km = KMeans(n_clusters=n_clusters, n_init=10, random_state=0).fit(activations)
    return km.labels_


def suspected_poison_indices(labels: np.ndarray, threshold: float = 0.35) -> np.ndarray:
    """Indices belonging to the smaller cluster if it's below threshold fraction."""
    sizes = np.bincount(labels)
    small = sizes.argmin()
    if sizes[small] / sizes.sum() < threshold:
        return np.where(labels == small)[0]
    return np.array([], dtype=int)
