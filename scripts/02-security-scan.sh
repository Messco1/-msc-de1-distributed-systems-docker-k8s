#!/usr/bin/env bash
# Step 3 - vulnerability scan (Trivy) + SBOM (Syft) of the final image.
source "$(dirname "$0")/lib.sh"; require_user
VERSION="${1:-1.0.0}"
IMG="${IMAGE_REPO}:${VERSION}"

start_log 06-security.txt "Vulnerability scan and SBOM for ${IMG}"
note "full Trivy report -> security/vulnerability-scan.txt"
{
  echo "Tool: Trivy ($(trivy_cmd --version 2>/dev/null | head -1))"
  echo "Image scanned: ${IMG}"
  echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  trivy_cmd image --scanners vuln,secret --format table "${IMG}"
} > security/vulnerability-scan.txt 2>&1
run "grep -E '^(Total|Report Summary|│ )' security/vulnerability-scan.txt | head -20 || true"

note "machine-readable report + counts by severity"
trivy_cmd image --scanners vuln --format json --quiet "${IMG}" > security/vulnerability-scan.json
run "python3 scripts/count_vulns.py security/vulnerability-scan.json"
run "python3 scripts/count_vulns.py security/vulnerability-scan.json --list HIGH,CRITICAL"

note "comparison with un-hardened alternatives (why slim + no pip)"
for ref in python:3.12 python:3.12-slim-trixie; do
  trivy_cmd image --scanners vuln --format json --quiet "$ref" > /tmp/cmp.json
  run "echo '$ref:'; python3 scripts/count_vulns.py /tmp/cmp.json"
done

note "SBOM (SPDX JSON + CycloneDX JSON)"
syft_cmd "${IMG}" -o spdx-json > security/sbom.spdx.json
syft_cmd "${IMG}" -o cyclonedx-json > security/sbom.cdx.json
run "ls -l security/"
run "python3 -c \"import json;d=json.load(open('security/sbom.spdx.json'));print(len(d['packages']),'packages in SBOM');print(sorted({p['name'] for p in d['packages'] if p.get('name','').lower() in ('flask','werkzeug','gunicorn','jinja2','python')}))\""
