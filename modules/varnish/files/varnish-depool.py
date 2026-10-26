#!/usr/bin/env python3

import os
import re
import json
import socket
import subprocess
import pyotp
from flask import Flask, Response, request

app = Flask(__name__)

# ========================================
# Load configuration from environment variables
# ========================================
app.config["TOTP_SECRET"] = os.environ.get("TOTP_SECRET")
PORT = int(os.environ.get("PORT", 5001))  # optional, default 5001
HAPROXY_SOCKET = os.environ.get("HAPROXY_SOCKET", "/run/haproxy/haproxy.sock")
HAPROXY_LB = "mediawiki_lb"

if not app.config["TOTP_SECRET"]:
    raise RuntimeError("TOTP_SECRET environment variable must be set")

# ========================================
# Helper Functions
# ========================================

def run_varnishadm(cmd):
    """Run varnishadm and return (returncode, stdout/stderr)"""
    result = subprocess.run(
        ["/usr/bin/varnishadm"] + cmd,
        capture_output=True, text=True
    )
    if result.returncode == 0:
        return 0, result.stdout.strip()
    else:
        return result.returncode, result.stderr.strip()

def haproxy_command(cmd):
    """Send one command to the HAProxy admin socket and return the reply"""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(5)
        sock.connect(HAPROXY_SOCKET)
        sock.sendall(cmd.encode() + b"\n")
        chunks = []
        while True:
            data = sock.recv(4096)
            if not data:
                break
            chunks.append(data)
    return b"".join(chunks).decode().strip()

def set_haproxy_state(name, state):
    """Mirror the Varnish state on the HAProxy balancer. Missing server or backend is fine"""
    target = "maint" if state == "sick" else "ready"
    try:
        reply = haproxy_command(f"set server {HAPROXY_LB}/{name} state {target}")
    except OSError:
        return False
    return reply == "" or reply.startswith("No such")

def json_response(data, status=200):
    """Return a Flask Response with JSON content"""
    return Response(json.dumps(data), status=status, mimetype="application/json")

def check_totp():
    """Check X-TOTP header"""
    totp_code = request.headers.get("X-TOTP", "")
    secret = app.config.get("TOTP_SECRET")
    if not totp_code or not secret:
        return False
    totp = pyotp.TOTP(secret)
    return totp.verify(totp_code, valid_window=1)  # allow ±1 interval

# ========================================
# Flask Hooks
# ========================================

@app.before_request
def enforce_security():
    if not check_totp():
        return json_response({"status": "error", "error": "unauthorized"}, status=401)

# ========================================
# Routes
# ========================================

@app.route("/backend/<name>/<state>", methods=["POST"])
def set_backend(name, state):
    if not re.match(r"^mw\d+$", name):
        return json_response({"status": "error", "error": "invalid backend name"}, status=400)

    state = state.lower()
    if state not in ["sick", "healthy", "auto"]:
        return json_response({"status": "error", "error": "invalid state"}, status=400)

    rc, _ = run_varnishadm(["backend.set_health", name, state])
    if rc != 0:
        return json_response({"status": "error", "error": "failed to set backend state"}, status=500)

    if not set_haproxy_state(name, state):
        return json_response({"status": "error", "error": "failed to set haproxy state"}, status=500)

    return json_response({"status": "ok"})

@app.route("/backend/list", methods=["GET"])
def list_backends():
    """Return only 'mw' backends (e.g., mw151), ignoring mwtask"""
    rc, out = run_varnishadm(["backend.list"])
    if rc != 0:
        return json_response({"status": "error", "error": "failed to list backends"}, status=500)

    filtered_lines = []
    for line in out.splitlines():
        if line.startswith("Backend name"):
            filtered_lines.append(line)
            continue
        if re.search(r"\.mw\d+\b", line):
            filtered_lines.append(line)

    return Response("\n".join(filtered_lines), mimetype="text/plain")

# ========================================
# Note for developers
# ========================================

if __name__ == "__main__":
    print("Running varnish-depool.py directly is only for development/testing.")
    print("Use Gunicorn to serve this app in production.")
