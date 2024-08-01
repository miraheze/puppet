#! /usr/bin/python3

import subprocess
import sys
subprocess.call(
    [
        '/usr/bin/firejail',
        '--profile=/etc/firejail/mediawiki-converters.profile',
        '--quiet',
        '/usr/bin/espeak',
    ]
    + sys.argv[1:],
)
