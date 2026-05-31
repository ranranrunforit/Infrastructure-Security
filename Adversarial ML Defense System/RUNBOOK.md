# Defense Runbook

When each defense applies, and how to deploy it.

## Evasion (adversarial inputs at inference)
- **Adversarial training** (`defenses/adversarial_training.py`): bake robustness into the model. Use when you control training and can afford ~3-7x training time. Choose `epsilon` matching the threat model.
- **Input validation** (`defenses/input_validation.py`): catch out-of-distribution inputs before they reach the model. Cheap, deploy as a FastAPI dependency in front of every endpoint.

## Poisoning (training-data tampering)
- **Activation clustering** (`defenses/backdoor_detection.py::activation_clustering`): run per-class on penultimate activations before deployment. A small cluster (<35%) signals likely poisoned samples; drop them and retrain.
- **Differential privacy** (`defenses/differential_privacy.py`): DP-SGD bounds the influence any single training sample can have, providing inherent poisoning resistance. Track `engine.get_epsilon(delta)` against your budget.

## Model extraction (stealing via queries)
- **Query budgets** (`defenses/rate_limit.py`): per-tenant daily cap on inference calls. Tune `daily_limit` based on legitimate workloads + a 2-3x headroom.
- **Watermarking** (`defenses/watermarking.py`): embed a trigger set before release. If you suspect a stolen model, call `verify`; agreement ≥70% on the secret labels is strong evidence.

## Membership inference
- **Differential privacy** is the principled defense. Empirically also lower confidence (temperature scaling) and avoid releasing per-sample losses.

## Backdoor attacks (trojan triggers)
- **Neural Cleanse** (`defenses/backdoor_detection.py::neural_cleanse`): run for each class on a held-out clean set. Any class whose reverse-engineered trigger has anomalously small L1(mask) is likely a backdoor target — retrain without suspected samples.
- **Activation clustering**: complementary at training time; Neural Cleanse works post-hoc.

## Benchmarking
Run `benchmark/robustness.py::measure` after any defense change to compare clean vs adversarial accuracy. Track `robustness_gap` over time.
