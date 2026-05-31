"""Watermark via backdoor-key set: model memorizes (trigger -> secret label) pairs.
Used to prove ownership of an extracted/stolen model."""
from __future__ import annotations

import torch


def make_trigger_set(n: int, input_shape: tuple, secret_label: int, seed: int = 1337):
    """Deterministic random inputs labeled with secret_label."""
    g = torch.Generator().manual_seed(seed)
    x = torch.rand((n, *input_shape), generator=g)
    y = torch.full((n,), secret_label, dtype=torch.long)
    return x, y


def embed(model, optimizer, trigger_x: torch.Tensor, trigger_y: torch.Tensor,
          epochs: int = 20) -> None:
    """Fine-tune model to memorize the trigger set."""
    model.train(True)
    for _ in range(epochs):
        optimizer.zero_grad()
        loss = torch.nn.functional.cross_entropy(model(trigger_x.cuda()), trigger_y.cuda())
        loss.backward(); optimizer.step()


def verify(model, trigger_x: torch.Tensor, trigger_y: torch.Tensor,
           threshold: float = 0.7) -> tuple[bool, float]:
    """Suspect model is derivative of ours if it agrees with secret labels above threshold."""
    model.train(False)
    with torch.no_grad():
        preds = model(trigger_x.cuda()).argmax(-1).cpu()
    acc = (preds == trigger_y).float().mean().item()
    return acc >= threshold, acc
