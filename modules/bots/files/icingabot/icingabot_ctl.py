#!/usr/bin/python3
import contextlib
import os
import sys

SIDES = ('irc', 'phorge')
USAGE = 'Usage: icingabot-ctl [irc|phorge|all] [off|on|status]'


def state(directory, side):
    paused = os.path.exists(os.path.join(directory, f'pause_{side}'))
    return f"{side}: {'paused' if paused else 'running'}"


def change(directory, side, action):
    path = os.path.join(directory, f'pause_{side}')
    if action == 'off':
        with open(path, 'w'):
            pass
        os.chmod(path, 0o644)
    else:
        with contextlib.suppress(FileNotFoundError):
            os.remove(path)
    return state(directory, side)


def main(args, directory):
    if not args or args == ['status']:
        args = ['all', 'status']
    if len(args) != 2 or args[0] not in (*SIDES, 'all') or args[1] not in ('off', 'on', 'status'):
        print(USAGE, file=sys.stderr)
        return 2
    side, action = args
    if not os.path.isdir(directory):
        print(f'{directory} does not exist, has the icingabot service started?', file=sys.stderr)
        return 1
    sides = SIDES if side == 'all' else (side,)
    try:
        for name in sides:
            print(state(directory, name) if action == 'status' else change(directory, name, action))
    except OSError as error:
        print(f'Could not change the pause file: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:], os.environ.get('ICINGABOT_STATE_DIR', '/var/lib/icingabot')))
