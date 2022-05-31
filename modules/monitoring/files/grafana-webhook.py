#! /usr/bin/env python3

from filelock import FileLock
import json
import time
import webhook_listener


def alert_to_irc(alerts):
    lock_acquired = False

    filename = '/tmp/tmp_webhook_file.lock'
    lock = FileLock(filename)

    while not lock_acquired:
        with lock:
            lock.acquire()
            try:
                messages = []
                for alert in alerts:
                    status = alert['status']

                    annotations = alert['annotations']
                    labels = alert['labels']
                    if 'summary' not in annotations:
                        continue

                    summary = annotations['summary']

                    page = ''
                    if 'page' in labels and labels['page'] == 'yes':
                       page = '!sre '

                    message = f'[Grafana] {page}{status}: {summary}'

                    dashboard = ''
                    if labels['team'] == 'mediawiki' and not alert['DashboardURL']:
                        dashboard = ' https://grafana.miraheze.org/d/GtxbP1Xnk/mediawiki'
                    elif alert['DashboardURL']:
                        dashboard = ' ' + alert['DashboardURL']

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
            finally:
                lock.release()
                lock_acquired = True
    return


def process_post_request(request, *args, **kwargs):
    body_raw = request.body.read(int(request.headers['Content-Length'])) if int(request.headers.get('Content-Length',0)) > 0 else '{}'
    body = json.loads(body_raw.decode('utf-8'))
    
    if 'alerts' in body:
        alert_to_irc(body['alerts'])

    return


webhooks = webhook_listener.Listener(handlers={'POST': process_post_request}, host='::', port=5100)
webhooks.start()

while True:
    time.sleep(300)
