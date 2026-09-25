# gunicorn.conf.py - production server configuration (overridable with env vars)
import os

bind = f"0.0.0.0:{os.environ.get('PORT', '8000')}"

# ONE worker process on purpose: the starter app keeps its items in memory,
# so several worker processes would each hold a different list. Concurrency is
# provided by threads inside that single process instead.
workers = 1
worker_class = "gthread"
threads = int(os.environ.get("GUNICORN_THREADS", "4"))

timeout = 30
graceful_timeout = 20          # time left to in-flight requests after SIGTERM
keepalive = 5

# Worker heartbeat files go to /tmp, mounted as tmpfs (Compose) or emptyDir
# (Kubernetes) -> compatible with a read-only root filesystem.
worker_tmp_dir = "/tmp"

# Gunicorn >= 26 opens a runtime control socket in $HOME by default; it is not
# needed here and $HOME is not writable with a read-only root filesystem.
control_socket_disable = True

accesslog = "-"                # stdout/stderr -> docker logs / kubectl logs
errorlog = "-"
loglevel = os.environ.get("LOG_LEVEL", "info")
