#!flask/bin/python3

from filelock import FileLock
from flask import Flask
from flask import request

app = Flask(__name__)


@app.route('/', methods=['POST'])
def post():
    lock_acquired = False

    content = request.get_json()

    filename = '/tmp/tmp_webhook_file.lock'
    lock = FileLock(filename)

    while not lock_acquired:
        with lock:
            lock.acquire()
            try:
                x = open('/var/log/icinga2/irc.log', 'a+')
                for alert in content['alerts']:
                    status = alert['status']
                    description = alert['annotations']['description']

                    page = ''
                    if alert['labels']['page'] == 'yes':
                       page = '!sre '

                    message = f'[Grafana] {page}{status}: {description}'

                    if alert['labels']['team'] == 'mediawiki' and not alert['labels']['dashboard']:
                        message += ' https://grafana.miraheze.org/d/GtxbP1Xnk/mediawiki'
                    x.write(message)
                x.close()
                lock_acquired = True
            finally:
                lock.release()
                lock_acquired = True
    return (message, 200, None)


app.run(host='::', port=5100, threaded=True)
