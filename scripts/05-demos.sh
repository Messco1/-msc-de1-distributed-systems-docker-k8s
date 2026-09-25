#!/usr/bin/env bash
# Step 6 - distributed-systems demonstrations.
# Prerequisite: tag 1.1.0 published (./scripts/03-publish.sh 1.1.0).
source "$(dirname "$0")/lib.sh"; require_user
SEL="app.kubernetes.io/name=flask-api"
pods() { kubectl -n $NS get pods -l $SEL -o wide; }

# ---------------------------------------------------------------- A -------
start_log 12-demo-service-discovery.txt "A. Replication, service discovery and network policy"
run "kubectl apply -f scripts/netpol-test-pods.yaml"
run "kubectl -n $NS wait --for=condition=Ready pod/client-allowed pod/client-denied --timeout=120s"
note "requests through the Service DNS name are load-balanced over the replicas"
run "for i in \$(seq 1 10); do kubectl -n $NS exec client-allowed -- curl -s http://flask-api/version; echo; done"
note "state is kept in memory PER POD: after one POST, GET /items differs by pod"
run "kubectl -n $NS exec client-allowed -- curl -s -X POST -H 'Content-Type: application/json' -d '{\"name\":\"only-on-one-pod\"}' http://flask-api/items"
run "for i in \$(seq 1 6); do kubectl -n $NS exec client-allowed -- curl -s http://flask-api/items; echo; done"
note "NetworkPolicy: pod without role=api-client label is blocked"
run_expect_fail "kubectl -n $NS exec client-denied -- curl -s -m 5 http://flask-api/health"
POD_IP=$(kubectl -n $NS get pods -l $SEL -o jsonpath='{.items[0].status.podIP}')
run_expect_fail "kubectl -n $NS exec client-denied -- curl -s -m 5 http://${POD_IP}:8000/health"
run "kubectl -n $NS exec client-allowed -- curl -s -m 5 http://${POD_IP}:8000/health"

# ---------------------------------------------------------------- B -------
start_log 13-demo-self-healing.txt "B. Self-healing"
run "kubectl -n $NS get pods -l $SEL -o wide"
VICTIM=$(kubectl -n $NS get pods -l $SEL -o jsonpath='{.items[0].metadata.name}')
run "kubectl -n $NS delete pod $VICTIM --wait=false"
run "sleep 2; kubectl -n $NS get pods -l $SEL -o wide"
run "kubectl -n $NS rollout status deployment/flask-api --timeout=120s"
run "kubectl -n $NS get pods -l $SEL -o wide"
run "kubectl -n $NS get events --sort-by=.lastTimestamp | grep -Ei 'killing|successfulcreate|scheduled' | tail -6"

# ---------------------------------------------------------------- C -------
start_log 14-demo-scaling.txt "C. Scaling 2 -> 3 -> 2"
run "kubectl -n $NS scale deployment/flask-api --replicas=3"
run "kubectl -n $NS rollout status deployment/flask-api --timeout=120s"
run "kubectl -n $NS get deploy flask-api"
run "kubectl -n $NS get pods -l $SEL -o wide"
run "kubectl -n $NS get endpointslices -l kubernetes.io/service-name=flask-api"
run "kubectl -n $NS scale deployment/flask-api --replicas=2"
run "sleep 15; kubectl -n $NS get deploy flask-api; kubectl -n $NS get pods -l $SEL -o wide"

# ---------------------------------------------------------------- D -------
start_log 15-demo-rolling-update.txt "D. Rolling update 1.0.0 -> 1.1.0 and rollback"
run "kubectl -n $NS rollout history deployment/flask-api"
run "kubectl -n $NS set image deployment/flask-api api=${IMAGE_REPO}:1.1.0"
run "kubectl -n $NS annotate deployment/flask-api kubernetes.io/change-cause='rolling update to image 1.1.0' --overwrite"
run "kubectl -n $NS rollout status deployment/flask-api --timeout=180s"
run "kubectl -n $NS get rs -o wide"
run "kubectl -n $NS rollout history deployment/flask-api"
run "for i in 1 2 3 4; do kubectl -n $NS exec client-allowed -- curl -s http://flask-api/version; echo; done"
note "rollback to the previous revision"
run "kubectl -n $NS rollout undo deployment/flask-api"
run "kubectl -n $NS annotate deployment/flask-api kubernetes.io/change-cause='rollback to image 1.0.0' --overwrite"
run "kubectl -n $NS rollout status deployment/flask-api --timeout=180s"
run "kubectl -n $NS rollout history deployment/flask-api"
run "kubectl -n $NS get deploy flask-api -o jsonpath='{.spec.template.spec.containers[0].image}{\"\n\"}'"
run "for i in 1 2 3 4; do kubectl -n $NS exec client-allowed -- curl -s http://flask-api/version; echo; done"

run "kubectl delete -f scripts/netpol-test-pods.yaml --wait=false"
note "final state = Git manifests (image 1.0.0, 2 replicas)"
run "kubectl -n $NS get deploy,pods -o wide"
