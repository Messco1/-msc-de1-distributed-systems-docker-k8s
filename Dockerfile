# syntax=docker/dockerfile:1
# =============================================================================
# MSc DE1 - Distributed Systems project
# Production-oriented image for the UBC Flask sample app.
#   Stage 1 "builder": create an isolated virtualenv with the pinned deps.
#   Stage 2 "test"    : optional stage that runs the unit tests (docker build --target test).
#   Stage 3 "runtime" : minimal image, non-root user, no pip, no compilers, no tests.
# =============================================================================

ARG PYTHON_IMAGE=python:3.12-slim-trixie

# ---------------------------------------------------------------- builder ----
FROM ${PYTHON_IMAGE} AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Dependency file first -> this layer is cached until requirements.txt changes.
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt \
 && pip uninstall -y pip \
 && rm -f /tmp/requirements.txt

# ------------------------------------------------------------------ test -----
FROM builder AS test
WORKDIR /src
COPY app/ ./app/
COPY tests/ ./tests/
RUN python -m unittest discover -v tests

# --------------------------------------------------------------- runtime -----
FROM ${PYTHON_IMAGE} AS runtime

ARG APP_VERSION=1.0.0

LABEL org.opencontainers.image.title="msc-de1-flask-app" \
      org.opencontainers.image.description="UBC Flask sample REST API - containerized for the MSc DE1 Distributed Systems project" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://github.com/ubc/flask-sample-app" \
      org.opencontainers.image.licenses="MIT"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:${PATH}" \
    APP_VERSION=${APP_VERSION} \
    PORT=8000

# Dedicated unprivileged user with a FIXED numeric UID/GID (10001) so that
# Kubernetes "runAsNonRoot" can verify it. No home directory, no login shell.
# The system pip is removed: it is not needed at runtime and only adds CVE surface.
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid 10001 --no-create-home \
            --home-dir /nonexistent --shell /usr/sbin/nologin app \
 && python -m pip uninstall -y pip \
 && rm -rf /root/.cache /tmp/*

WORKDIR /app

# Only what is needed at runtime. Files stay owned by root and are therefore
# read-only for the "app" user (the code cannot be modified by the process).
COPY --from=builder /opt/venv /opt/venv
COPY app/ ./app/
COPY gunicorn.conf.py ./

USER 10001:10001

EXPOSE 8000

# Health check without curl/wget: uses the Python interpreter already present.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/health' % os.environ.get('PORT', '8000'), timeout=2)"]

# Exec form: gunicorn is PID 1 and receives SIGTERM directly (graceful shutdown).
STOPSIGNAL SIGTERM
ENTRYPOINT ["gunicorn", "--config", "gunicorn.conf.py"]
CMD ["app:app"]
