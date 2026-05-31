# Benchmarks

These scripts produce the evidence for the non-functional requirements:

- NFR-001: service mesh and mTLS add less than 5 ms p95 latency per hop.
- NFR-002: zero-trust controls add less than 15 percent monthly infrastructure cost.

## Performance

Run one endpoint outside the mesh as the baseline and the protected `iris-api`
endpoint through Istio as the mesh path:

```bash
export BASELINE_URL=http://baseline.example.com/predict
export MESH_URL=http://iris-api.example.com/predict
bash benchmarks/performance/compare.sh
```

The script writes `benchmarks/performance/results.json`.

## Cost

Provide monthly cost numbers from the baseline cluster and the zero-trust
cluster, then compare:

```bash
export BASELINE_MONTHLY_USD=1000
export ZERO_TRUST_MONTHLY_USD=1125
bash benchmarks/cost/compare.sh
```

The script writes `benchmarks/cost/results.json`.
