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
        # llvm-cov segments: [line, col, count, hasCount, isRegionEntry, isGapRegion]
        zero = sorted({s[0] for s in f.get("segments", []) if s[3] and s[4] and not s[5] and s[2] == 0})
        name = f["filename"].split("/Sources/InvoiceKit/")[1]
        gaps.append(f'{name} {lines["covered"]}/{lines["count"]}, lines {zero}')
pct = 100.0 * covered / total if total else 100.0
print(f"::notice title=InvoiceKit coverage::{pct:.1f}% of {total} lines")
for g in gaps[:9]:
    print(f"::warning title=Uncovered lines::{g}")
sys.exit(0 if pct >= minimum else 1)
