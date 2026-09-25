# app/routes.py

import os
import socket

from app import app
from flask import request

items = []

# Version injected at image build time (Dockerfile ARG/ENV APP_VERSION).
APP_VERSION = os.environ.get("APP_VERSION", "dev")


@app.route('/')
def hello():
    return "Hello, Flask!"


@app.route('/items', methods=['GET'])
def get_items():
    return {'items': items}


@app.route('/items/<int:item_id>', methods=['GET'])
def get_item(item_id):
    if item_id < len(items):
        return {'item': items[item_id]}
    else:
        return {'error': 'Item not found'}, 404


@app.route('/items', methods=['POST'])
def add_item():
    item = request.get_json()
    items.append(item)
    return {'message': 'Item added successfully'}, 201


# --- Added for containerization / orchestration (original routes unchanged) ---

@app.route('/health', methods=['GET'])
def health():
    """Lightweight endpoint used by the Docker HEALTHCHECK and Kubernetes probes."""
    return {'status': 'ok'}, 200


@app.route('/version', methods=['GET'])
def version():
    """Returns the image version and the serving host (pod name in Kubernetes)."""
    return {'version': APP_VERSION, 'hostname': socket.gethostname()}, 200
