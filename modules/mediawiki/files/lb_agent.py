#!/usr/bin/env python3
"""HAProxy agent check for MediaWiki servers.

Each connection gets one line such as "72% maxconn:18" and is closed.
"""

import argparse
import http.client
import json
import math
import os
import socketserver
import threading
import time


class Sampler:
    def __init__(self, args):
        self.status_port = args.status_port
        self.status_timeout = args.status_timeout
        self.min_pct = args.min_pct
        self.ttl = args.cache_ttl
        self.lb_count = args.lb_count
        self.overcommit = args.maxconn_overcommit
        self.lock = threading.Lock()
        self.stamp = float('-inf')
        self.reply = f'{self.min_pct}%'

    def fpm_status(self):
        conn = http.client.HTTPConnection('127.0.0.1', self.status_port, timeout=self.status_timeout)
        try:
            conn.request('GET', '/php_status?json', headers={'Host': 'localhost'})
            resp = conn.getresponse()
            if resp.status != 200:
                return None
            return json.loads(resp.read())
        except (OSError, ValueError, http.client.HTTPException):
            return None
        finally:
            conn.close()

    def compute(self):
        status = self.fpm_status()
        cores = os.cpu_count() or 1
        headroom = max(0.0, 1.0 - os.getloadavg()[0] / cores)
        total = 0
        free = 0.0
        if status is not None:
            total = int(status.get('total processes', 0))
            if total > 0 and int(status.get('listen queue', 0)) == 0:
                free = int(status.get('idle processes', 0)) / total
        pct = max(self.min_pct, min(100, int(100 * min(free, headroom))))
        reply = f'{pct}%'
        if total > 0 and self.overcommit > 0:
            reply += f' maxconn:{max(1, math.ceil(total * self.overcommit / self.lb_count))}'
        return reply

    def get(self):
        with self.lock:
            now = time.monotonic()
            if now - self.stamp >= self.ttl:
                self.reply = self.compute()
                self.stamp = now
            return self.reply


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.settimeout(2)
        self.request.sendall(f'{self.server.sampler.get()}\n'.encode())


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, address, sampler):
        self.sampler = sampler
        super().__init__(address, Handler)


def parse_args():
    parser = argparse.ArgumentParser(description='HAProxy agent check for MediaWiki servers.')
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--status-port', type=int, default=80)
    parser.add_argument('--status-timeout', type=float, default=1.0)
    parser.add_argument('--cache-ttl', type=float, default=1.0)
    parser.add_argument('--min-pct', type=int, default=10)
    parser.add_argument('--lb-count', type=int, default=1)
    parser.add_argument('--maxconn-overcommit', type=float, default=1.5)
    args = parser.parse_args()
    args.lb_count = max(1, args.lb_count)
    return args


def main():
    args = parse_args()
    with Server(('0.0.0.0', args.port), Sampler(args)) as server:
        server.serve_forever()


if __name__ == '__main__':
    main()
