#!flask/bin/python

from filelock import FileLock
from flask import Flask
app = Flask(__name__)
from flask import Flask
from flask import request
import os
import time

app = Flask(__name__)

@app.route('/renew', methods=['POST'])
def post():
    lock_acquired = False

    content = request.get_json()

    filename = '/tmp/tmp_file.lock'
    lock = FileLock(filename)

    while not lock_acquired:
        try:
            with lock.acquire():
                os.system("/var/lib/nagios/ssl-acme -s {} -t {} -u {} >> /var/log/acme/ssl-renew.log 2>&1".format(
                    content['SERVICESTATE'],
                    content['SERVICESTATETYPE'],
                    content['SERVICEDESC']
                ))
                time.sleep(2)
                lock_acquired = True
        finally:
            lock.release()
            lock_acquired = True
    return '', 204

app.run(host='0.0.0.0', port=5000, threaded=True)
