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

    while not lock_acquired:

        try:
            with FileLock(filename):
                os.system("sudo -u nagiosre /var/lib/nagios/ssl-acme -a {} -s {} -t {} -u {}".format(
                    content['SERVICEATTEMPT'],
                    content['SERVICESTATE'],
                    content['SERVICESTATETYPE'],
                    content['SERVICEDESC']
                ))
                time.sleep(2)
                lock_acquired = True
        finally:
            os.unlink(filename)
            lock_acquired = True
    return '', 204

app.run(host='0.0.0.0', port=5000)
