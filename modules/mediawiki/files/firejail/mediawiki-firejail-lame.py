#! /usr/bin/python3

import subprocess
import sys
subprocess.call(
    [
        '/usr/bin/firejail',
        '--profile=/etc/firejail/mediawiki-converters.profile',
        '--quiet',
        '/usr/bin/lame',
    ]
    + sys.argv[1:],
)
