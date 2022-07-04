#!flask/bin/python3

import logging
import os

from filelock import FileLock

from flask import Flask
from flask import request

app = Flask(__name__)

logging.basicConfig(filename='/var/log/ssl/miraheze-renewal.log', format='%(asctime)s - %(message)s', level=logging.DEBUG, force=True)


@app.route('/renew', methods=['POST'])
def post():
    lock_acquired = False

    content = request.get_json()

    filename = '/tmp/tmp_file.lock'
    lock = FileLock(filename)

    while not lock_acquired:
        with lock:
            lock.acquire()
            try:
                logging.info(f'Renewed SSL certificate: {content["SERVICEDESC"]}')
                os.system(f'/var/lib/nagios/ssl-acme -s {content["SERVICESTATE"]} -t {content["SERVICESTATETYPE"]} -u {content["SERVICEDESC"]} >> /var/log/ssl/ssl-renew.log 2>&1')
                lock_acquired = True
            finally:
                lock.release()
                lock_acquired = True
    return '', 204


app.run(host='::', port=5000, threaded=True)
