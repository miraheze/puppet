#!/usr/bin/env python3
"""Nagios check for the servers of the HAProxy load balancer pools.

Critical when a server is down, warning when one is depooled or draining.
"""

import argparse
import csv
import io
import os
import re
import socket
import sys

PREFIX = 'lb_'
SOCKETS = ['/run/haproxy/haproxy.sock', '/run/haproxy/admin.sock']
NODE_NAME = re.compile(r'[a-z]+\d+')


def find_socket():
    for path in SOCKETS:
        if os.path.exists(path):
            return path
    return SOCKETS[0]


def stat(sock_path):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(5)
        sock.connect(sock_path)
        sock.sendall(b'show stat\n')
        chunks = []
        while True:
            data = sock.recv(4096)
            if not data:
                break
            chunks.append(data)
    return b''.join(chunks).decode()


def describe(rows):
    return ', '.join(f"{name} ({pool})" for pool, name in rows)


def main():
    parser = argparse.ArgumentParser(description='Check the servers of the HAProxy load balancer pools.')
    parser.add_argument('-s', '--socket', default=find_socket())
    args = parser.parse_args()

    try:
        out = stat(args.socket)
    except OSError as e:
        print(f'UNKNOWN: cannot read HAProxy stats: {e}')
        sys.exit(3)

    down, admin, total = [], [], 0
    for row in csv.DictReader(io.StringIO(out.lstrip('# '))):
        if not row['pxname'].startswith(PREFIX) or not NODE_NAME.fullmatch(row['svname']):
            continue
        total += 1
        entry = (row['pxname'][len(PREFIX):], row['svname'])
        status = row['status']
        if status.startswith('DOWN'):
            down.append(entry)
        elif status.startswith(('MAINT', 'DRAIN', 'NOLB')):
            admin.append(entry)

    if not total:
        print('UNKNOWN: no pool servers found')
        sys.exit(3)
    if down:
        suffix = f'; depooled: {describe(admin)}' if admin else ''
        print(f'CRITICAL: {len(down)} backend{"s" if len(down) != 1 else ""} down: {describe(down)}{suffix}')
        sys.exit(2)
    if admin:
        print(f'WARNING: {len(admin)} backend{"s" if len(admin) != 1 else ""} depooled or draining: {describe(admin)}')
        sys.exit(1)
    print(f'OK: all {total} backends are up')
    sys.exit(0)


if __name__ == '__main__':
    main()
