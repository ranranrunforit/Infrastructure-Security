#!/usr/bin/env bash
# Tabletop injection scripts — simulate incident signals during a game day.
# Run each scenario in a separate terminal; the facilitator triggers them
# at the moments scripted in q1-tabletop.md.
#
# Cross-ref: engineer-solutions/mod-108 exercise-09-incident-response-gameday
# for the full fault-injection harness.

set -euo pipefail

SCENARIO="${1:-help}"
NAMESPACE="${NAMESPACE:-soc-tabletop}"
INFERENCE_URL="${INFERENCE_URL:-http://inference-gateway.${NAMESPACE}.svc.cluster.local}"
VICTIM_TOKEN="${VICTIM_TOKEN:-eyJhbGc...REPLACE...}"

inject_model_theft() {
  # Simulate stolen API key being used for high-rate diverse-input queries.
  echo "[scenario A] injecting model-extraction pattern (50k qps over 10 min)"
  for i in $(seq 1 50000); do
    payload=$(head -c 256 /dev/urandom | base64)
    curl -sS -o /dev/null -X POST "${INFERENCE_URL}/v1/predict" \
      -H "Authorization: Bearer ${VICTIM_TOKEN}" \
      -H "X-Source-IP: 178.124.${RANDOM:0:3}.${RANDOM:0:2}" \
      -d "{\"input\":\"${payload}\"}" &
    if (( i % 200 == 0 )); then wait; fi
  done
  wait
}

inject_data_poisoning() {
  # Push a corrupted batch into the staging dataset bucket to simulate a
  # poisoned vendor feed landing in the nightly retrain.
  echo "[scenario B] injecting poisoned vendor feed into staging dataset"
  python3 - <<'PY'
import csv, random
with open("/tmp/poisoned_batch.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["user_id", "feature_1", "feature_2", "label"])
    for i in range(10000):
        # Label-flip attack on protected demographic A.
        demo = random.choice(["A", "B", "C"])
        true_label = random.randint(0, 1)
        label = 1 - true_label if demo == "A" else true_label
        w.writerow([i, random.gauss(0, 1), random.gauss(0, 1), label])
print("wrote /tmp/poisoned_batch.csv")
PY
  aws s3 cp /tmp/poisoned_batch.csv \
    "s3://${NAMESPACE}-staging-datasets/vendor-feed/$(date +%Y-%m-%d)/batch.csv"
}

inject_adversarial_dos() {
  # Spray adversarial inputs from a rotating source-IP pool to exhaust GPU.
  echo "[scenario C] injecting adversarial-DoS pattern (200 IPs, heavy inputs)"
  for ip_suffix in $(seq 1 200); do
    (
      for j in $(seq 1 500); do
        # Large input to drive compute cost per request.
        payload=$(head -c 8192 /dev/urandom | base64)
        curl -sS -o /dev/null -X POST "${INFERENCE_URL}/v1/predict" \
          -H "X-Forwarded-For: 45.61.${ip_suffix}.${RANDOM:0:2}" \
          -d "{\"input\":\"${payload}\",\"adversarial_seed\":${j}}"
      done
    ) &
  done
  wait
}

case "$SCENARIO" in
  A|model-theft)        inject_model_theft ;;
  B|data-poisoning)     inject_data_poisoning ;;
  C|adversarial-dos)    inject_adversarial_dos ;;
  *)
    cat <<EOF
Usage: $0 {A|B|C}
  A | model-theft       — Scenario A: stolen API key, model extraction
  B | data-poisoning    — Scenario B: poisoned vendor feed
  C | adversarial-dos   — Scenario C: adversarial DoS
Env: NAMESPACE, INFERENCE_URL, VICTIM_TOKEN
EOF
    exit 1
    ;;
esac
