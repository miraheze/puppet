#!flask/bin/python

from flask import Flask
app = Flask(__name__)
from flask import Flask
from flask import request
import subprocess
import os

app = Flask(__name__)

@app.route('/renew', methods=['POST'])
def post():
    content = request.get_json()
    lock_acquired = False
    while not lock_acquired:
        try:
            os.system("/var/lib/nagios/ssl-acme -a {} -s {} -t {} -u {}".format(
	            content['SERVICEATTEMPT'],
	            content['SERVICESTATE'],
	            content['SERVICESTATETYPE'],
	            content['SERVICEDESC']
	        ))
        except:
            sleep(3)
        else:
            lock_acquired = True
    lock_acquired = False
    return '', 204

app.run(host='0.0.0.0', port=5000)
