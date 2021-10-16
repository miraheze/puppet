#!flask/bin/python3

from filelock import FileLock
from flask import Flask
from flask import request
import os

app = Flask(__name__)

@app.route('/ ', methods=['POST'])
def post():
    lock_acquired = False

    content = request.get_json()

    filename = '/tmp/tmp_webhook_file.lock'
    lock = FileLock(filename)

    while not lock_acquired:
        with lock:
            lock.acquire()
            try:
                message = content['state'] + ' : ' + content['title']
                if content['alerts'][0]['labels']['team'] == 'mediawiki':
                    message = message + ' https://grafana.miraheze.org/d/dsHv5-4nz/mediawiki?orgId=1'
                x = open('/var/log/icinga2/irc.log', 'a+')
                x.write(message)
                x.close()
                lock_acquired = True
            finally:
                lock.release()
                lock_acquired = True
    return (message, 200, None)


app.run(host='0.0.0.0', port=5100, threaded=True)
