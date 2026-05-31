"""DP-SGD training with Opacus; tracks privacy budget (epsilon, delta)."""
from __future__ import annotations

import torch
from opacus import PrivacyEngine


def make_private(model, optimizer, loader,
                 noise_multiplier: float = 1.1, max_grad_norm: float = 1.0):
    """Wrap model/optimizer/loader with Opacus PrivacyEngine. Returns wrapped trio + engine."""
    engine = PrivacyEngine()
    model, optimizer, loader = engine.make_private(
        module=model,
        optimizer=optimizer,
        data_loader=loader,
        noise_multiplier=noise_multiplier,
        max_grad_norm=max_grad_norm,
    )
    return model, optimizer, loader, engine


def spent_budget(engine: PrivacyEngine, delta: float = 1e-5) -> float:
    """Current epsilon spent under (epsilon, delta)-DP."""
    return engine.get_epsilon(delta=delta)


def train_epoch(model, loader, optimizer) -> float:
    model.train(True)
    total = n = 0
    for x, y in loader:
        x, y = x.cuda(), y.cuda()
        optimizer.zero_grad()
        loss = torch.nn.functional.cross_entropy(model(x), y)
        loss.backward()
        optimizer.step()
        total += loss.item() * y.size(0)
        n += y.size(0)
    return total / n
