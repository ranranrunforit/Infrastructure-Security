# Adversarial ML Defense System

Reusable Python modules for testing and defending ML models against common adversarial ML threats:

- Evasion attacks at inference time
- Training-data poisoning
- Model extraction through queries
- Membership inference
- Backdoor and trojan triggers

The project is organized as small attack, defense, and benchmark utilities. It does not define a fixed model architecture or dataset; pass in your own PyTorch models, dataloaders, tensors, and service dependencies.

## Project Layout

```text
attacks/
  pgd.py                    # Native PyTorch PGD plus ART and Foolbox PGD wrappers
  poisoning.py              # Label-flip poisoning
  extraction.py             # Query-based surrogate training and agreement scoring
  membership_inference.py   # Per-sample loss and threshold attack
  backdoor.py               # BadNets-style trigger stamping and attack success rate
  textattack_nlp.py         # TextAttack recipe runner for NLP models

defenses/
  adversarial_training.py   # PGD adversarial training epoch
  input_validation.py       # IsolationForest request validation and FastAPI dependency
  rate_limit.py             # Redis-backed per-tenant query budget
  differential_privacy.py   # Opacus DP-SGD wrapper and budget reporting
  backdoor_detection.py     # Neural Cleanse and activation clustering helpers
  watermarking.py           # Trigger-set watermark embedding and verification

benchmark/
  robustness.py             # Defense effectiveness metrics

RUNBOOK.md                  # When to apply each defense
REQUIREMENTS.md             # Project requirements
```

## Dependencies

Core modules expect:

- PyTorch
- NumPy
- scikit-learn
- Redis Python client
- FastAPI, only for the input-validation dependency helper
- Opacus, for DP-SGD
- Adversarial Robustness Toolbox, for `art_pgd`
- Foolbox, for `foolbox_pgd`
- TextAttack, for NLP attack recipes

Install only the optional tools you need for the modules you run. For example, the native PGD attack does not require ART or Foolbox.

## Attacks

`attacks/pgd.py` generates evasion examples with projected gradient descent. It includes:

- `pgd(...)` for a direct PyTorch implementation
- `art_pgd(...)` for Adversarial Robustness Toolbox classifiers
- `foolbox_pgd(...)` for Foolbox PyTorch models

`attacks/poisoning.py` provides `label_flip(...)` for untargeted or source-to-target label poisoning.

`attacks/extraction.py` trains a surrogate model from victim softmax outputs and measures surrogate/victim agreement.

`attacks/membership_inference.py` computes per-sample losses and chooses a loss threshold that best separates member from non-member examples.

`attacks/backdoor.py` stamps a trigger patch, poisons a dataset toward a target label, and measures attack success rate.

`attacks/textattack_nlp.py` runs a supplied TextAttack recipe against a TextAttack-compatible model wrapper and dataset.

## Defenses

`defenses/adversarial_training.py` trains one epoch on PGD-generated adversarial examples.

`defenses/input_validation.py` fits an IsolationForest on training samples and rejects out-of-distribution inference requests. `fastapi_dependency(...)` adapts it for FastAPI endpoints.

`defenses/rate_limit.py` implements Redis-backed daily query budgets per tenant to limit extraction attempts.

`defenses/differential_privacy.py` wraps a model, optimizer, and dataloader with Opacus DP-SGD and reports the spent epsilon budget.

`defenses/backdoor_detection.py` includes:

- `neural_cleanse(...)` to reverse-engineer small class-specific triggers
- `activation_clustering(...)` to cluster penultimate activations
- `suspected_poison_indices(...)` to identify small suspicious clusters

`defenses/watermarking.py` creates a secret trigger set, embeds it by fine-tuning, and verifies ownership of a suspected extracted model.

## Benchmark Metrics

`benchmark/robustness.py` contains small metric helpers:

- `measure(...)`: clean accuracy, PGD adversarial accuracy, and robustness gap
- `validation_rejection_rate(...)`: input-validator rejection rate
- `membership_inference_accuracy(...)`: threshold attack accuracy
- `extraction_agreement(...)`: surrogate/victim prediction agreement
- `backdoor_attack_success_rate(...)`: target-class success on triggered inputs
- `watermark_ownership_score(...)`: watermark verification result and score

Use these metrics before and after enabling a defense to confirm that the defense is actually affecting the relevant threat.

## Basic Usage

```python
from attacks.pgd import pgd
from defenses.adversarial_training import train_epoch
from benchmark.robustness import measure

x_adv = pgd(model, x, y, epsilon=8 / 255, alpha=2 / 255, steps=10)
loss = train_epoch(model, train_loader, optimizer, epsilon=8 / 255)
metrics = measure(model, test_loader, epsilon=8 / 255)
```

```python
from defenses.differential_privacy import make_private, spent_budget

model, optimizer, private_loader, engine = make_private(model, optimizer, train_loader)
epsilon = spent_budget(engine, delta=1e-5)
```

```python
from defenses.watermarking import make_trigger_set, embed, verify

trigger_x, trigger_y = make_trigger_set(32, input_shape=(3, 32, 32), secret_label=7)
embed(model, optimizer, trigger_x, trigger_y)
owned, score = verify(suspect_model, trigger_x, trigger_y)
```

## Notes

- Most model-facing utilities assume tensors are already normalized into `[0, 1]`.
- Several training and evaluation helpers call `.cuda()`, so run them with CUDA models/tensors or adapt the device handling for CPU-only use.
- `RUNBOOK.md` explains when each defense should be applied.
