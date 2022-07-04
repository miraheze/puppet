#! /usr/bin/python3

import sys
from os import system

system(f'disable-puppet "{sys.argv[1]}"')
input('press enter to re-enable puppet')
system('enable-puppet')
