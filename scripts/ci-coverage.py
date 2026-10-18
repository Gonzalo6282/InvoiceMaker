#!/usr/bin/env python3
"""Print InvoiceKit line coverage as GitHub annotations. Usage: ci-coverage.py <codecov.json> <minimum %>"""
import json, sys

data = json.load(open(sys.argv[1]))
minimum = float(sys.argv[2])
covered = total = 0
gaps = []
for f in data["data"][0]["files"]:
    if "/Sources/InvoiceKit/" not in f["filename"]:
        continue
    lines = f["summary"]["lines"]
    covered += lines["covered"]
    total += lines["count"]
    if lines["covered"] < lines["count"]:
        gaps.append(f'{f["filename"].split("/Sources/InvoiceKit/")[1]} {lines["covered"]}/{lines["count"]}')
pct = 100.0 * covered / total if total else 100.0
print(f"::notice title=InvoiceKit coverage::{pct:.1f}% of {total} lines")
for g in gaps[:9]:
    print(f"::warning title=Uncovered lines::{g}")
sys.exit(0 if pct >= minimum else 1)
