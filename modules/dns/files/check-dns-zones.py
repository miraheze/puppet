#! /usr/bin/python3

# Loops over all zonefiles and passes them through named-checkzone
# Exits with error if named-checkzone does
# Checks are in local mode

import os
import subprocess

dir = os.fsencode('/etc/bind/zones/')
for file in os.listdir(dir):
    filename = os.fsdecode(file)
    subprocess.run(['/usr/bin/named-checkzone', '-i local', filename, f'/etc/bind/zones/{filename}'], check=True)
