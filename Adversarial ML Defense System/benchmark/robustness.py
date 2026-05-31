"""Benchmark robustness: clean accuracy vs adversarial accuracy."""
from __future__ import annotations

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "attacks"))

import torch
from membership_inference import threshold_attack
from pgd import pgd


def accuracy(model, loader) -> float:
    model.train(False)
    correct = total = 0
    for x, y in loader:
        x, y = x.cuda(), y.cuda()
        with torch.no_grad():
            correct += (model(x).argmax(-1) == y).sum().item()
        total += y.size(0)
    return correct / total


def adversarial_accuracy(model, loader, epsilon: float = 0.03) -> float:
    model.train(False)
    correct = total = 0
    for x, y in loader:
        x, y = x.cuda(), y.cuda()
        x_adv = pgd(model, x, y, epsilon=epsilon)
        with torch.no_grad():
            correct += (model(x_adv).argmax(-1) == y).sum().item()
        total += y.size(0)
    return correct / total


def measure(model, test_loader, epsilon: float = 0.03) -> dict:
    """Returns clean acc + adversarial acc."""
    clean_acc = accuracy(model, test_loader)
    adv_acc = adversarial_accuracy(model, test_loader, epsilon=epsilon)
    return {
        "clean_acc": clean_acc,
        "adversarial_acc": adv_acc,
        "robustness_gap": clean_acc - adv_acc,
    }


def validation_rejection_rate(validator, X) -> float:
    """Fraction of requests rejected by the input validator."""
    accepted, _ = validator.filter_batch(X)
    return 1.0 - (len(accepted) / len(X))


def membership_inference_accuracy(member_losses, nonmember_losses) -> float:
    """Attack accuracy; lower is better after DP-SGD."""
    _, attack_acc = threshold_attack(member_losses, nonmember_losses)
    return attack_acc


def extraction_agreement(surrogate, victim, loader) -> float:
    """Surrogate/victim agreement; lower is better after query budgets."""
    from extraction import agreement

    return agreement(surrogate, victim, loader)


def backdoor_attack_success_rate(model, X_clean, target_label: int,
                                 patch_size: int = 3) -> float:
    """Triggered target-class rate; lower is better after backdoor defenses."""
    from backdoor import attack_success_rate

    return attack_success_rate(model, X_clean, target_label, patch_size=patch_size)


def watermark_ownership_score(model, trigger_x, trigger_y,
                              threshold: float = 0.7) -> dict:
    """Watermark verification result for suspected extracted models."""
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "defenses"))
    from watermarking import verify

    owned, score = verify(model, trigger_x, trigger_y, threshold=threshold)
    return {"owned": owned, "score": score}
