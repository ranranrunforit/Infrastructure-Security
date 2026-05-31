"""Membership inference: decide if a sample was in the training set via loss thresholding."""
from __future__ import annotations

import numpy as np
import torch


def per_sample_loss(model, loader) -> np.ndarray:
    model.train(False)
    losses = []
    for x, y in loader:
        x, y = x.cuda(), y.cuda()
        with torch.no_grad():
            logits = model(x)
            l = torch.nn.functional.cross_entropy(logits, y, reduction="none")
        losses.append(l.cpu().numpy())
    return np.concatenate(losses)


def threshold_attack(member_losses: np.ndarray, nonmember_losses: np.ndarray) -> tuple[float, float]:
    """Pick loss threshold maximizing membership-inference accuracy; return (threshold, accuracy)."""
    scores = np.concatenate([member_losses, nonmember_losses])
    truth = np.concatenate([np.ones_like(member_losses), np.zeros_like(nonmember_losses)])
    best_t = best_acc = 0.0
    for t in np.unique(scores):
        pred = (scores <= t).astype(np.float32)
        acc = (pred == truth).mean()
        if acc > best_acc:
            best_acc, best_t = acc, float(t)
    return best_t, float(best_acc)
