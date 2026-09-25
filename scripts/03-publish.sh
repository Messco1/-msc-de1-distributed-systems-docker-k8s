#!/usr/bin/env bash
# Step 4 - publish a multi-architecture image (amd64 + arm64) to Docker Hub,
# then delete local copies, pull it back and verify it works.
#   ./scripts/03-publish.sh 1.0.0      (first release, also tagged latest)
#   ./scripts/03-publish.sh 1.1.0      (update used for the rolling-update demo)
source "$(dirname "$0")/lib.sh"; require_user
VERSION="${1:?usage: 03-publish.sh <version>}"
C=flask-api-pulled

start_log "07-publish-${VERSION}.txt" "Docker Hub publication of ${IMAGE_REPO}:${VERSION}"
note "log in interactively (credentials are stored by Docker, never in the repo)"
docker login -u "${DOCKERHUB_USER}"

docker buildx inspect msc-builder >/dev/null 2>&1 || docker buildx create --name msc-builder --driver docker-container >/dev/null
run "docker buildx build --builder msc-builder --platform linux/amd64,linux/arm64 --target runtime --build-arg APP_VERSION=${VERSION} --provenance=true --sbom=true -t ${IMAGE_REPO}:${VERSION} -t ${IMAGE_REPO}:latest --push ."
run "docker buildx imagetools inspect ${IMAGE_REPO}:${VERSION}"

note "remove every local copy + build cache, then pull from Docker Hub"
run "docker rmi -f ${IMAGE_REPO}:${VERSION} ${IMAGE_REPO}:latest 2>/dev/null || true"
run "docker builder prune -f >/dev/null && echo build cache pruned"
run "docker pull ${IMAGE_REPO}:${VERSION}"
run "docker image inspect -f 'RepoDigests={{json .RepoDigests}}' ${IMAGE_REPO}:${VERSION}"

docker rm -f $C >/dev/null 2>&1 || true
run "docker run -d --name $C -p 127.0.0.1:8080:8000 --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges:true ${IMAGE_REPO}:${VERSION}"
wait_healthy $C
run "curl -s http://127.0.0.1:8080/ ; echo; curl -s http://127.0.0.1:8080/version"
run "curl -s -X POST -H 'Content-Type: application/json' -d '{\"name\": \"from-hub\"}' http://127.0.0.1:8080/items; curl -s http://127.0.0.1:8080/items/0"
run "docker rm -f $C"
note "public page: https://hub.docker.com/r/${DOCKERHUB_USER}/${IMAGE_NAME}"
