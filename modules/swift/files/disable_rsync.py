#!/usr/bin/env python

import errno
import os
import shutil

# Percentage
RESERVE = 1

DEVICES = '/srv/node'
path_template = '/etc/rsync.disable//frag-disable_%s.conf'
config_template = '''
[object_%s]
max connections = -1
'''

def disable_rsync(device):
    with open(path_template % device, 'w') as f:
        f.write(config_template.lstrip() % device)


def enable_rsync(device):
    try:
        os.unlink(path_template % device)
    except OSError as e:
        # ignore file does not exist
        if e.errno != errno.ENOENT:
            raise


for device in os.listdir(DEVICES):
    path = os.path.join(DEVICES, device)
    total, _, free = shutil.disk_usage(path)
    if ((free/total) * 100) < RESERVE:
        disable_rsync(device)
    else:
        enable_rsync(device)
