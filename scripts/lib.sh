#!/usr/bin/env bash
# Shared helpers: every command is echoed and its output appended to an
# evidence file under evidence/command-output/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
EVIDENCE_DIR="$ROOT/evidence/command-output"
mkdir -p "$EVIDENCE_DIR" "$ROOT/security"

NS="msc-de1-project"
CLUSTER="msc-de1"
IMAGE_NAME="msc-de1-flask-app"
LOG_FILE="/dev/null"

require_user() {
  : "${DOCKERHUB_USER:?Please run: export DOCKERHUB_USER=<your-dockerhub-username>}"
  IMAGE_REPO="docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}"
  export DOCKERHUB_USER IMAGE_REPO
}

start_log() {   # start_log <file> <title>
  LOG_FILE="$EVIDENCE_DIR/$1"
  {
    echo "# $2"
    echo "# generated $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(uname -sm)"
  } > "$LOG_FILE"
  echo -e "\n========== $2 ==========\n(evidence -> ${LOG_FILE#$ROOT/})"
}

run() {         # run "<command>"  : must succeed
  echo -e "\n\$ $1" | tee -a "$LOG_FILE"
  bash -c "$1" 2>&1 | tee -a "$LOG_FILE"
}

run_expect_fail() {   # run "<command>" : failure is the expected result
  echo -e "\n\$ $1    # expected to FAIL" | tee -a "$LOG_FILE"
  if bash -c "$1" 2>&1 | tee -a "$LOG_FILE"; then
    echo "!! command unexpectedly succeeded" | tee -a "$LOG_FILE"
  else
    echo "-> failed as expected (exit code != 0)" | tee -a "$LOG_FILE"
  fi
}

note() { echo -e "\n# $*" | tee -a "$LOG_FILE"; }

wait_healthy() {  # wait_healthy <container>
  for _ in $(seq 1 30); do
    s=$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null || echo none)
    [ "$s" = "healthy" ] && { note "container $1 is healthy"; return 0; }
    sleep 2
  done
  echo "container $1 did not become healthy" >&2; docker logs "$1" >&2; return 1
}

trivy_cmd() {   # native trivy if installed, else the official container
  if command -v trivy >/dev/null 2>&1; then trivy "$@"
  else docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
         -v "$HOME/.cache/trivy:/root/.cache/trivy" "${TRIVY_IMAGE:-aquasec/trivy:0.69.3}" "$@"
  fi
}

syft_cmd() {
  if command -v syft >/dev/null 2>&1; then syft "$@"
  else docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
         "${SYFT_IMAGE:-anchore/syft:v1.18.1}" "$@"
  fi
}
export -f trivy_cmd syft_cmd
