#!/usr/bin/env bash
# Replace the YOUR_DOCKERHUB_USER placeholder in the committed files.
#   ./scripts/set-dockerhub-user.sh jdoe
set -euo pipefail
cd "$(dirname "$0")/.."
U="${1:?usage: set-dockerhub-user.sh <dockerhub-username>}"
for f in k8s/deployment.yaml README.md .env.example compose.yaml; do
  sed -i.bak -e "s/YOUR_DOCKERHUB_USER/${U}/g" -e "s/yourdockerhubuser/${U}/g" "$f" && rm -f "$f.bak"
done
grep -n "image:" k8s/deployment.yaml compose.yaml
