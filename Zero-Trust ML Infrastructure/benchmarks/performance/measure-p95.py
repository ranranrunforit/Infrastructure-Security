#!/usr/bin/env python3
import argparse
import json
import statistics
import time
import urllib.request


BODY = json.dumps(
    {"features": {"sepal_length": 6.1, "petal_length": 4.7}}
).encode("utf-8")


def request(url):
    req = urllib.request.Request(
        url,
        data=BODY,
        method="POST",
        headers={"content-type": "application/json"},
    )
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=5) as response:
        response.read()
    return (time.perf_counter() - start) * 1000


def p95(values):
    values = sorted(values)
    index = int((len(values) - 1) * 0.95)
    return values[index]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--requests", type=int, default=200)
    parser.add_argument("--warmup", type=int, default=20)
    args = parser.parse_args()

    for _ in range(args.warmup):
        request(args.url)

    latencies = [request(args.url) for _ in range(args.requests)]
    result = {
        "requests": args.requests,
        "p50_ms": round(statistics.median(latencies), 3),
        "p95_ms": round(p95(latencies), 3),
        "max_ms": round(max(latencies), 3),
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
