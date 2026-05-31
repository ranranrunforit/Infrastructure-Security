#!/usr/bin/env python3
"""Build or verify a tamper-evident hash chain for audit log files."""

import argparse
import hashlib
import json
from pathlib import Path


def digest_file(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build(logs, out):
    previous = "0" * 64
    entries = []
    for path in logs:
        file_hash = digest_file(path)
        chain_hash = hashlib.sha256(f"{previous}:{file_hash}:{path.name}".encode()).hexdigest()
        entries.append(
            {
                "file": path.name,
                "file_hash": file_hash,
                "previous_hash": previous,
                "chain_hash": chain_hash,
            }
        )
        previous = chain_hash
    out.write_text(json.dumps(entries, indent=2) + "\n", encoding="utf-8")


def verify(logs, chain):
    entries = json.loads(chain.read_text(encoding="utf-8"))
    if len(entries) != len(logs):
        raise SystemExit("chain length does not match log count")

    previous = "0" * 64
    for path, entry in zip(logs, entries):
        file_hash = digest_file(path)
        expected = hashlib.sha256(f"{previous}:{file_hash}:{path.name}".encode()).hexdigest()
        if entry["file"] != path.name or entry["file_hash"] != file_hash:
            raise SystemExit(f"log hash mismatch: {path.name}")
        if entry["previous_hash"] != previous or entry["chain_hash"] != expected:
            raise SystemExit(f"chain hash mismatch: {path.name}")
        previous = expected
    print("audit hash chain valid")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["build", "verify"])
    parser.add_argument("--chain", required=True, type=Path)
    parser.add_argument("logs", nargs="+", type=Path)
    args = parser.parse_args()

    logs = sorted(args.logs)
    if args.mode == "build":
        build(logs, args.chain)
    else:
        verify(logs, args.chain)


if __name__ == "__main__":
    main()
