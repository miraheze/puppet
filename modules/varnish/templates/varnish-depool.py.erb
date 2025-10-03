#!flask/bin/python3

from flask import Flask, Response, request
import subprocess
import json
import re
import pyotp
import argparse

app = Flask(__name__)

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

@app.before_request
def enforce_security():
    if not check_totp():
        return json_response({"status": "error", "error": "unauthorized"}, status=401)

@app.route("/backend/<name>/<state>", methods=["POST"])
def set_backend(name, state):
    # Only allow backend names starting with 'mw' followed by numbers
    if not re.match(r"^mw\d+$", name):
        return json_response({"status": "error", "error": "invalid backend name"}, status=400)

    state = state.lower()
    if state not in ["sick", "healthy", "auto"]:
        return json_response({"status": "error", "error": "invalid state"}, status=400)

    # Set backend health
    rc, _ = run_varnishadm(["backend.set_health", name, state])
    if rc != 0:
        return json_response({"status": "error", "error": "failed to set backend state"}, status=500)

    return json_response({"status": "ok"})

@app.route("/backend/list", methods=["GET"])
def list_backends():
    """Return only 'mw' backends (e.g., mw151), ignoring mwtask"""
    rc, out = run_varnishadm(["backend.list"])
    if rc != 0:
        return json_response({"status": "error", "error": "failed to list backends"}, status=500)

    filtered_lines = []
    for line in out.splitlines():
        # Keep header
        if line.startswith("Backend name"):
            filtered_lines.append(line)
            continue
        # Match backend containing '.mw' followed by numbers
        if re.search(r"\.mw\d+\b", line):
            filtered_lines.append(line)

    return Response("\n".join(filtered_lines), mimetype="text/plain")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Varnish API Flask wrapper with TOTP auth")
    parser.add_argument("--totp-secret", required=True, help="TOTP shared secret (base32)")
    parser.add_argument("--port", type=int, default=5001, help="Port to listen on (default: 5001)")
    args = parser.parse_args()

    # store secret in app config
    app.config["TOTP_SECRET"] = args.totp_secret

    app.run(host="::", port=args.port, threaded=True)
