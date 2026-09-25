#!/usr/bin/env bash
# Step 5 - create the kind cluster and deploy the Docker Hub image.
source "$(dirname "$0")/lib.sh"; require_user

if grep -q YOUR_DOCKERHUB_USER k8s/deployment.yaml; then
  echo "k8s/deployment.yaml still contains YOUR_DOCKERHUB_USER -> run ./scripts/set-dockerhub-user.sh" >&2; exit 1
fi

start_log 08-kind-cluster.txt "kind cluster (1 control-plane + 2 workers)"
run "kind version && kubectl version --client"
if ! kind get clusters | grep -qx "$CLUSTER"; then
  run "kind create cluster --config kind/kind-config.yaml --wait 120s"
fi
run "kubectl cluster-info --context kind-${CLUSTER}"
run "kubectl get nodes -o wide"

start_log 09-k8s-deploy.txt "Deploy manifests in namespace ${NS}"
run "kubectl apply -f k8s/namespace.yaml"
run "kubectl apply -f k8s/"
run "kubectl -n $NS rollout status deployment/flask-api --timeout=180s"
run "kubectl -n $NS get deploy,rs,pods,svc,netpol,cm -o wide"
run "kubectl -n $NS get pods -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP,IMAGE:.spec.containers[0].image,STATUS:.status.phase"
note "the Service selects exactly the Deployment's pods (compare IPs above)"
run "kubectl -n $NS describe svc flask-api"
run "kubectl -n $NS get endpointslices -l kubernetes.io/service-name=flask-api -o wide"
run "kubectl -n $NS get pods -l app.kubernetes.io/name=flask-api --show-labels"

start_log 10-k8s-security.txt "Effective security settings of a running pod"
POD=$(kubectl -n $NS get pods -l app.kubernetes.io/name=flask-api -o jsonpath='{.items[0].metadata.name}')
run "kubectl -n $NS get pod $POD -o jsonpath='{.spec.securityContext}{\"\n\"}{.spec.containers[0].securityContext}{\"\n\"}{.spec.containers[0].resources}{\"\n\"}'"
run "kubectl -n $NS exec $POD -- id"
run "kubectl -n $NS exec $POD -- sh -c 'touch /app/x 2>&1; grep -E \"^Cap(Prm|Eff)\" /proc/1/status; grep Seccomp: /proc/1/status'"
run "kubectl get ns $NS --show-labels"
note "Pod Security Admission (restricted) rejects a pod with default (root) settings:"
run_expect_fail "kubectl -n $NS run bad --image=busybox:1.36 --restart=Never -- sleep 1"

start_log 11-k8s-access.txt "Access through the Service (port-forward)"
kubectl -n $NS port-forward svc/flask-api 8080:80 >/tmp/pf.log 2>&1 &
PF=$!; trap 'kill $PF 2>/dev/null || true' EXIT; sleep 3
run "curl -s -i http://127.0.0.1:8080/"
run "curl -s http://127.0.0.1:8080/version"
run "curl -s -X POST -H 'Content-Type: application/json' -d '{\"name\": \"k8s-item\"}' http://127.0.0.1:8080/items"
run "curl -s http://127.0.0.1:8080/items/0"
run "curl -s -w ' HTTP %{http_code}\n' http://127.0.0.1:8080/items/99"
