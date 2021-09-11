#!flask/bin/python3

from filelock import FileLock
from flask import Flask
from flask import request
import os

app = Flask(__name__)


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
                os.system("/var/lib/nagios/ssl-acme -s {} -t {} -u {} > /var/log/letsencrypt/ssl-renew.log 2>&1".format(
                    content['SERVICESTATE'],
                    content['SERVICESTATETYPE'],
                    content['SERVICEDESC']
                ))
                lock_acquired = True
            finally:
                lock.release()
                lock_acquired = True
    return '', 204


app.run(host='0.0.0.0', port=5000, threaded=True)
