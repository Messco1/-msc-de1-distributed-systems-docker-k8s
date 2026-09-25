#!/usr/bin/env bash
# Remove everything created locally by the project.
set -uo pipefail
cd "$(dirname "$0")/.."
docker compose down --remove-orphans 2>/dev/null
docker rm -f flask-api-test flask-api-pulled 2>/dev/null
kind delete cluster --name msc-de1
docker buildx rm msc-builder 2>/dev/null
echo "Cleanup done."
