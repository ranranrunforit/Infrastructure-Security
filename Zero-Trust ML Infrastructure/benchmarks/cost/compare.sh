#!/usr/bin/env bash
# Compare monthly baseline and zero-trust cluster cost for NFR-002.
set -euo pipefail

: "${BASELINE_MONTHLY_USD:?set baseline monthly cost}"
: "${ZERO_TRUST_MONTHLY_USD:?set zero-trust monthly cost}"

OUT="${OUT:-$(dirname "$0")/results.json}"

python3 - "$BASELINE_MONTHLY_USD" "$ZERO_TRUST_MONTHLY_USD" "$OUT" <<'PY'
import json
import sys

baseline = float(sys.argv[1])
zero_trust = float(sys.argv[2])
out = sys.argv[3]
increase = ((zero_trust - baseline) / baseline) * 100
result = {
    "baseline_monthly_usd": round(baseline, 2),
    "zero_trust_monthly_usd": round(zero_trust, 2),
    "increase_percent": round(increase, 2),
    "nfr_002_pass": increase < 15,
}
open(out, "w", encoding="utf-8").write(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
PY
