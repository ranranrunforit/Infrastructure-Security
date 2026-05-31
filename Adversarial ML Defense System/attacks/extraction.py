"""Model extraction: train a surrogate from query/response pairs."""
from __future__ import annotations

import torch


def query_victim(victim, x: torch.Tensor) -> torch.Tensor:
    victim.train(False)
    with torch.no_grad():
        return victim(x).softmax(-1)


def train_surrogate(surrogate, victim, query_loader, optimizer, epochs: int = 5) -> None:
    """Distill victim's softmax outputs into surrogate via KL divergence."""
    for _ in range(epochs):
        surrogate.train(True)
        for x, _ in query_loader:
            x = x.cuda()
            y_soft = query_victim(victim, x)
            optimizer.zero_grad()
            log_p = torch.nn.functional.log_softmax(surrogate(x), dim=-1)
            loss = torch.nn.functional.kl_div(log_p, y_soft, reduction="batchmean")
            loss.backward(); optimizer.step()


def agreement(surrogate, victim, loader) -> float:
    """Fraction of test inputs where surrogate predicts the same class as victim."""
    surrogate.train(False); victim.train(False)
    agree = total = 0
    for x, _ in loader:
        x = x.cuda()
        with torch.no_grad():
            agree += (surrogate(x).argmax(-1) == victim(x).argmax(-1)).sum().item()
        total += x.size(0)
    return agree / total
