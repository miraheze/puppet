#!/usr/bin/env python
import os
import errno

RESERVE = 10000 * 2 ** 20  # 10G

DEVICES = '/srv/node1'

path_template = '/etc/rsync.d/disable_%s.conf'
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
    st = os.statvfs(path)
    free = st.f_bavail * st.f_frsize
    if free < RESERVE:
        disable_rsync(device)
    else:
        enable_rsync(device)
