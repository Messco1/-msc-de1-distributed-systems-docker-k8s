#!/usr/bin/env bash
# Step 1 - prove the ORIGINAL application works without Docker.
source "$(dirname "$0")/lib.sh"
PORT_BASE=5000   # Flask dev server default (macOS: disable AirPlay Receiver if busy)

start_log 01-baseline.txt "Baseline - original application without Docker"
run "python3 --version"
run "python3 -m venv .venv"
run ".venv/bin/pip install --quiet -r requirements.txt && .venv/bin/pip freeze"
run ".venv/bin/python -m unittest discover -v tests"

note "starting the app with the original launch script: python run.py"
.venv/bin/python run.py > /tmp/baseline-app.log 2>&1 &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null || true' EXIT
sleep 3
run "curl -s -i http://127.0.0.1:${PORT_BASE}/"
run "curl -s -i http://127.0.0.1:${PORT_BASE}/items"
run "curl -s -i -X POST -H 'Content-Type: application/json' -d '{\"name\": \"item1\"}' http://127.0.0.1:${PORT_BASE}/items"
run "curl -s -i http://127.0.0.1:${PORT_BASE}/items"
run "curl -s -i http://127.0.0.1:${PORT_BASE}/items/0"
run "curl -s -i http://127.0.0.1:${PORT_BASE}/items/5"
kill $APP_PID; sleep 1
run "cat /tmp/baseline-app.log"
