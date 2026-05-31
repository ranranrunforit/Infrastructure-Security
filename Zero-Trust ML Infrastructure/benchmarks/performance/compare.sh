#!/usr/bin/env bash
# Compare baseline and mesh p95 latency for NFR-001.
set -euo pipefail

: "${BASELINE_URL:?set BASELINE_URL, for example http://baseline/predict}"
: "${MESH_URL:?set MESH_URL, for example http://iris-api.example.com/predict}"

REQUESTS="${REQUESTS:-200}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-$HERE/results.json}"

BASELINE_JSON="$(python3 "$HERE/measure-p95.py" "$BASELINE_URL" --requests "$REQUESTS")"
MESH_JSON="$(python3 "$HERE/measure-p95.py" "$MESH_URL" --requests "$REQUESTS")"

python3 - "$OUT" "$BASELINE_JSON" "$MESH_JSON" <<'PY'
import json
import sys

out, baseline_raw, mesh_raw = sys.argv[1:]
baseline = json.loads(baseline_raw)
mesh = json.loads(mesh_raw)
overhead = mesh["p95_ms"] - baseline["p95_ms"]
result = {
    "baseline": baseline,
    "mesh": mesh,
    "p95_overhead_ms": round(overhead, 3),
    "nfr_001_pass": overhead < 5,
}
open(out, "w", encoding="utf-8").write(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
PY
