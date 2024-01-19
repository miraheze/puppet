#!flask/bin/python3

from filelock import FileLock
from flask import Flask
from flask import request
import logging
import logging.handlers
import subprocess

app = Flask(__name__)

formatter = logging.Formatter('%(asctime)s - %(message)s', '%m-%d-%Y %I:%M:%S %p')
handler = logging.handlers.TimedRotatingFileHandler('/var/log/ssl/miraheze-renewal.log', 'midnight', 1)
handler.setFormatter(formatter)
logger = logging.getLogger()
logger.addHandler(handler)
logger.setLevel(logging.INFO)


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
                logger.info(f'Renewed SSL certificate: {content["SERVICEDESC"]}')
                logger.info(subprocess.run(f'/var/lib/nagios/ssl-acme -s {content["SERVICESTATE"]} -t {content["SERVICESTATETYPE"]} -u {content["SERVICEDESC"]}', stderr=subprocess.STDOUT, shell=True))
                lock_acquired = True
            finally:
                lock.release()
                lock_acquired = True
    return '', 204


app.run(host='::', port=5000, threaded=True)
