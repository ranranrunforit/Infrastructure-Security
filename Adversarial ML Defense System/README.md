# Project 3 Adversarial Defense

## Layout

```
project-3-adversarial-defense/
├── README.md
├── defenses/
│   ├── adversarial_training.py     # PGD-based hardening
│   ├── input_validation.py          # anomaly detection on inference
│   ├── dp_sgd.py                    # differential privacy at training
│   └── rate_limit.py                # per-tenant query budgets
├── attacks/
│   ├── pgd.py                       # projected gradient descent
│   ├── model_extraction.py          # query-based extraction
│   └── membership_inference.py
└── benchmark/
    └── robustness.py                # accuracy under attack
```
