"""PGD adversarial training: train model on adversarial examples for robustness."""
from __future__ import annotations

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "attacks"))

import torch
from pgd import pgd


def train_epoch(model, loader, optimizer,
                epsilon: float = 0.03, alpha: float = 0.01, steps: int = 7) -> float:
    """One epoch of PGD adversarial training. Returns mean loss."""
    model.train(True)
    total_loss = n = 0
    for x, y in loader:
        x, y = x.cuda(), y.cuda()
        x_adv = pgd(model, x, y, epsilon=epsilon, alpha=alpha, steps=steps)
        optimizer.zero_grad()
        loss = torch.nn.functional.cross_entropy(model(x_adv), y)
        loss.backward()
        optimizer.step()
        total_loss += loss.item() * y.size(0)
        n += y.size(0)
    return total_loss / n
