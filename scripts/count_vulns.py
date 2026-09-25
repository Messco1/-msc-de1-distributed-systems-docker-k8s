#!/usr/bin/env python3
"""Count Trivy JSON findings by severity; optionally list some severities."""
import json
import sys
from collections import Counter

path = sys.argv[1]
wanted = sys.argv[3].split(",") if len(sys.argv) > 3 and sys.argv[2] == "--list" else []
data = json.load(open(path))
counts, seen = Counter(), set()
for result in data.get("Results", []):
    for v in result.get("Vulnerabilities") or []:
        key = (v["VulnerabilityID"], v["PkgName"], v.get("InstalledVersion"))
        if key in seen:
            continue
        seen.add(key)
        counts[v["Severity"]] += 1
        if v["Severity"] in wanted:
            print(f'{v["Severity"]:8} {v["VulnerabilityID"]:18} {v["PkgName"]} '
                  f'{v.get("InstalledVersion")} -> fixed: {v.get("FixedVersion") or "none"} '
                  f'[{result.get("Target")}]')
if not wanted:
    order = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"]
    print("  ".join(f"{s}={counts.get(s, 0)}" for s in order), f" TOTAL={sum(counts.values())}")
