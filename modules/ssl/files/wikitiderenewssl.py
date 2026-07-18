#!/usr/bin/env python3
from filelock import FileLock
from flask import Flask, request
import logging
import logging.handlers
import subprocess

app = Flask(__name__)

# Configure logging
formatter = logging.Formatter('%(asctime)s - %(message)s', '%m-%d-%Y %I:%M:%S %p')
handler = logging.handlers.TimedRotatingFileHandler(
    '/var/log/ssl/wikitide-renewal.log',
    when='midnight',
    interval=1,
    backupCount=7
)
handler.setFormatter(formatter)
logger = logging.getLogger()
logger.addHandler(handler)
logger.setLevel(logging.INFO)

@app.route('/renew', methods=['POST'])
def post():
    content = request.get_json() or {}
    
    # Extract data safely with defaults
    service_desc = content.get("SERVICEDESC", "unknown")
    service_state = content.get("SERVICESTATE", "unknown")
    state_type = content.get("SERVICESTATETYPE", "unknown")

    filename = '/tmp/tmp_file.lock'
    lock = FileLock(filename)

    # Use the context manager properly to handle acquiring/releasing automatically
    with lock:
        logger.info(f'Renewed SSL certificate: {service_desc}')
        
        # Array argument format protects against shell injection vulnerabilities
        command = subprocess.run([
            '/var/lib/nagios/ssl-acme',
            '-s', service_state,
            '-t', state_type,
            '-u', service_desc
        ], capture_output=True, text=True)
        
        if command.stdout:
            logger.info(command.stdout.strip())
        if command.stderr:
            logger.info(command.stderr.strip())

    return '', 204
