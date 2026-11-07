#!/usr/bin/env python3
"""Inspect and change the load balancer pools of this cache host.

  lb-ctl status [pool]
  lb-ctl maint|drain|ready <server> [--pool POOL]

Changes only affect the HAProxy on this host. Use safe-service-restart to
change a server on every cache host.
"""

import argparse
import csv
import io
import os
import re
import socket
import sys

SOCKET = '/run/haproxy/haproxy.sock'
STATE_FILE = '/var/lib/haproxy/server-state'
PREFIX = 'lb_'
NODE_NAME = re.compile(r'[a-z]+\d+')
STATES = ('maint', 'drain', 'ready')
COLUMNS = ['pool', 'server', 'status', 'weight', 'scur', 'qcur', 'check_status', 'check_code', 'last_chk', 'last_agt']


def command(sock_path, cmd):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(5)
        sock.connect(sock_path)
        sock.sendall(cmd.encode() + b'\n')
        chunks = []
        while True:
            data = sock.recv(4096)
            if not data:
                break
            chunks.append(data)
    return b''.join(chunks).decode().strip()


def servers(sock_path, pool=None):
    out = command(sock_path, 'show stat')
    rows = []
    for row in csv.DictReader(io.StringIO(out.lstrip('# '))):
        if not row['pxname'].startswith(PREFIX) or not NODE_NAME.fullmatch(row['svname']):
            continue
        row['pool'] = row['pxname'][len(PREFIX):]
        row['server'] = row['svname']
        if pool is None or row['pool'] == pool:
            rows.append(row)
    return sorted(rows, key=lambda r: (r['pool'], r['server']))


def print_table(rows):
    table = [COLUMNS] + [[(row.get(col) or '-') for col in COLUMNS] for row in rows]
    widths = [max(len(line[i]) for line in table) for i in range(len(COLUMNS))]
    for line in table:
        print('  '.join(cell.ljust(width) for cell, width in zip(line, widths)).rstrip())


def save_state(sock_path, state_file):
    tmp = state_file + '.tmp'
    with open(tmp, 'w') as fh:
        fh.write(command(sock_path, 'show servers state') + '\n')
    os.replace(tmp, state_file)


def change(args):
    if not NODE_NAME.fullmatch(args.server):
        sys.exit(f'Invalid server name: {args.server}')
    rows = [r for r in servers(args.socket, args.pool) if r['server'] == args.server]
    if not rows:
        sys.exit(f'{args.server} is not in any pool' + (f' {args.pool}' if args.pool else ''))
    for row in rows:
        reply = command(args.socket, f"set server {row['pxname']}/{args.server} state {args.action}")
        if reply:
            sys.exit(f"{row['pxname']}/{args.server}: {reply}")
        print(f"{row['pool']}/{args.server}: {args.action}")
    try:
        save_state(args.socket, args.state_file)
    except OSError as e:
        print(f'Could not save server state, it is lost on restart: {e}', file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description='Inspect and change the load balancer pools of this host.')
    parser.add_argument('--socket', default=SOCKET)
    parser.add_argument('--state-file', default=STATE_FILE)
    sub = parser.add_subparsers(dest='action', required=True)
    status = sub.add_parser('status', help='show all servers of all pools')
    status.add_argument('pool', nargs='?')
    for name in STATES:
        cmd = sub.add_parser(name, help=f'set the server to {name}')
        cmd.add_argument('server')
        cmd.add_argument('--pool')
    args = parser.parse_args()

    try:
        if args.action == 'status':
            print_table(servers(args.socket, args.pool))
        else:
            change(args)
    except PermissionError:
        sys.exit('Permission denied, run with sudo')
    except OSError as e:
        sys.exit(f'Cannot reach HAProxy at {args.socket}: {e}')


if __name__ == '__main__':
    main()
