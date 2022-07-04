#!flask/bin/python3

from filelock import FileLock
from flask import Flask
from flask import request

app = Flask(__name__)


@app.route('/', methods=['POST'])
def post():
    status_code = 500
    lock_acquired = False

    content = request.get_json()

    filename = '/tmp/tmp_webhook_file.lock'
    lock = FileLock(filename)

    while not lock_acquired:
        with lock:
            lock.acquire()
            try:
                messages = []
                for alert in content['alerts']:
                    status = alert['status']

                    if status == 'firing' and 'summary' in alert['annotations']:
                        body = alert['annotations']['summary']
                    else:
                        body = alert['labels']['alertname']

                    page = ''
                    if 'page' in alert['labels']:
                        page = '!sre '

                    message = f'[Grafana] {page}{status.upper()}: {body}'

                    if alert['dashboardURL']:
                        dashboard = ' ' + alert['dashboardURL'].replace('http://', 'https://', 1)

                        # We don't want to truncate part of a URL if it's going to be truncated below
                        if len(message + dashboard) <= 450:
                            message += dashboard

                    # Truncate the message to guarantee it will fit in an IRC message
                    if len(message) > 450:
                        message = message[:447] + '...'

                    messages.append( f'{message}\n' )

                irc = open('/var/log/icinga2/irc.log', 'a')
                irc.writelines(messages)
                irc.close()

                lock_acquired = True
                status_code = 204
            finally:
                lock.release()
                lock_acquired = True
    return '', status_code


app.run(host='::', port=5100, threaded=True)
