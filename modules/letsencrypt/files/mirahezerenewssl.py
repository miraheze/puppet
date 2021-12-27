#!flask/bin/python3

from filelock import FileLock
from flask import Flask, jsonify, request
import logging
import os
from waitress import serve

app = Flask(__name__)

logging.basicConfig(filename='/var/log/letsencrypt/miraheze-renewal.log', format='%(asctime)s - %(message)s', level=logging.DEBUG)


@app.route('/renew', methods=['POST'])
def post():
    lock_acquired = False

    content = request.get_json()

    filename = '/tmp/tmp_file.lock'
    lock = FileLock(filename)

    ssl_acme = 0
    while not lock_acquired:
        with lock:
            lock.acquire()
            try:
                logging.info("Renewed ssl certificate: {}".format(content['SERVICEDESC']))
                ssl_acme = os.system("/var/lib/nagios/ssl-acme -s {} -t {} -u {} >> /var/log/letsencrypt/ssl-renew.log 2>&1".format(
                    content['SERVICESTATE'],
                    content['SERVICESTATETYPE'],
                    content['SERVICEDESC']
                ))
                lock_acquired = True
            finally:
                lock.release()
                lock_acquired = True

    if ssl_acme != 0:
        return jsonify(success=False)

    return jsonify(success=True)


serve(app, listen='*:5001')
