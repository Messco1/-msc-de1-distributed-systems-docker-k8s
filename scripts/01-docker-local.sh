#!/usr/bin/env bash
# Step 2 - build, run, inspect and stop the image locally; then Docker Compose.
source "$(dirname "$0")/lib.sh"; require_user
VERSION="${1:-1.0.0}"
C=flask-api-test

start_log 02-docker-build.txt "Docker build (tests stage + runtime image ${VERSION})"
run "docker version --format 'client {{.Client.Version}} / server {{.Server.Version}}'"
run "docker build --target test -t ${IMAGE_REPO}:test ."
run "docker build --target runtime --build-arg APP_VERSION=${VERSION} -t ${IMAGE_REPO}:${VERSION} ."

start_log 03-docker-inspect.txt "Image inspection"
run "docker image ls ${IMAGE_REPO}"
run "docker image inspect -f 'Size: {{.Size}} bytes' ${IMAGE_REPO}:${VERSION}"
run "docker history --no-trunc --format 'table {{.Size}}\t{{.CreatedBy}}' ${IMAGE_REPO}:${VERSION} | cut -c1-160"
run "docker image inspect -f 'User={{.Config.User}}  ExposedPorts={{json .Config.ExposedPorts}}' ${IMAGE_REPO}:${VERSION}"
run "docker image inspect -f 'Entrypoint={{json .Config.Entrypoint}}  Cmd={{json .Config.Cmd}}  StopSignal={{.Config.StopSignal}}' ${IMAGE_REPO}:${VERSION}"
run "docker image inspect -f 'Healthcheck={{json .Config.Healthcheck}}' ${IMAGE_REPO}:${VERSION}"
run "docker image inspect -f 'Env={{json .Config.Env}}' ${IMAGE_REPO}:${VERSION}"
run "docker run --rm --entrypoint sh ${IMAGE_REPO}:${VERSION} -c 'which pip gcc curl wget apt-get || true'"

start_log 04-docker-run.txt "Run the container (hardened flags) and test the API"
docker rm -f $C >/dev/null 2>&1 || true
run "docker run -d --name $C -p 127.0.0.1:8080:8000 --read-only --tmpfs /tmp:size=16m,noexec,nosuid,nodev --cap-drop ALL --security-opt no-new-privileges:true --memory 256m --cpus 0.5 --pids-limit 100 ${IMAGE_REPO}:${VERSION}"
wait_healthy $C
run "docker ps --filter name=$C --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
run "curl -s -i http://127.0.0.1:8080/"
run "curl -s http://127.0.0.1:8080/items"
run "curl -s -X POST -H 'Content-Type: application/json' -d '{\"name\": \"item1\"}' http://127.0.0.1:8080/items"
run "curl -s http://127.0.0.1:8080/items/0"
run "curl -s -w ' HTTP %{http_code}\n' http://127.0.0.1:8080/items/5"
run "curl -s http://127.0.0.1:8080/health; echo; curl -s http://127.0.0.1:8080/version"
note "user identity inside the container (must NOT be root/uid 0)"
run "docker exec $C id"
run "docker top $C -o user,pid,args"
run "docker exec $C sh -c 'touch /app/hack 2>&1; touch /tmp/ok && echo /tmp is writable'"
run "docker inspect -f 'Health={{.State.Health.Status}} ReadOnly={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} SecOpt={{.HostConfig.SecurityOpt}} Privileged={{.HostConfig.Privileged}}' $C"
run "docker logs $C"
note "graceful stop: gunicorn (PID 1) receives SIGTERM"
run "time docker stop $C"
run "docker logs --tail 4 $C"
run "docker rm $C"

start_log 05-compose.txt "Docker Compose"
run "docker compose config"
run "docker compose up -d"
wait_healthy "$(docker compose ps -q api)"
run "docker compose ps"
run "curl -s http://127.0.0.1:8080/version"
run "docker compose exec api id"
run "docker compose logs api"
run "docker compose down"
