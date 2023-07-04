#!/usr/bin/env python

import errno
import os
import shutil

# Percentage
RESERVE = 1

DEVICES = '/srv/node'

path_template = '/etc/rsync.d/frag-objects_disable_%s.conf'
config_template = '''
[object_%s]
max connections = -1
'''

def applyConfig(device):
    os.system("cat /etc/rsync.d/header /etc/rsync.d/frag-* > /etc/rsyncd.conf")
    os.system("service rsync restart")


def disable_rsync(device):
    if not os.path.isfile(path_template % device):
        with open(path_template % device, 'w') as f:
            f.write(config_template.lstrip() % device)
        if os.path.isfile(path_template % device):
            applyConfig(device)


def enable_rsync(device):
    if os.path.isfile(path_template % device):
        os.unlink(path_template % device)


for device in os.listdir(DEVICES):
    path = os.path.join(DEVICES, device)
    total, _, free = shutil.disk_usage(path)
    if ((free/total) * 100) < RESERVE:
        disable_rsync(device)
    else:
        enable_rsync(device)
