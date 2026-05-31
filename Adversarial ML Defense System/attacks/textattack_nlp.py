"""TextAttack wrapper for NLP adversarial examples."""
from __future__ import annotations


def run_textattack_recipe(model_wrapper, dataset, recipe_cls, num_examples: int = 20):
    """Run a TextAttack recipe against an NLP model wrapper."""
    from textattack import AttackArgs, Attacker

    attack = recipe_cls.build(model_wrapper)
    args = AttackArgs(num_examples=num_examples, disable_stdout=True)
    return Attacker(attack, dataset, args).attack_dataset()
