# Changelog

## 1.1.0
- Version bump used for the Kubernetes rolling-update / rollback demonstration.
  Only the build argument `APP_VERSION` changes: `GET /version` now returns `"1.1.0"`.

## 1.0.0
- Starter app (UBC flask-sample-app) containerized: multi-stage Dockerfile, non-root user
  (UID 10001), Gunicorn production server, Docker health check.
- Added `GET /health` (probes) and `GET /version` (image version + serving pod).
  All original routes and tests unchanged.
- Dependencies: all versions pinned; `gunicorn` added.
