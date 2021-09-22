#! /usr/bin/python3

import os.path

files = [
    '/etc/ssl/certs',
    '/etc/ssl/localcerts',
    '/usr/share/ca-certificates/mozilla'
]

with open('/etc/vmtouch-files.list', mode='wt') as filesList:
    filesList.write('\n'.join(files))
    filesList.write('\n')

# After writing to file we restart the service to pickup the changes.
os.system('sudo service vmtouch restart')
