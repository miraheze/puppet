#! /usr/bin/python3

import sys
from os import system

system(f'logsalmsg Disabling puppet for {sys.argv[1]}')
system('sudo puppet agent -tv')
system(f'sudo puppet agent --disable "{sys.argv[1]}"')
