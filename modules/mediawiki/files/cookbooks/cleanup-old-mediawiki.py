#! /usr/bin/python3

from os import system
import sys

version = sys.argv[1]

system('sudo rm /srv/mediawiki/cache/legacy-wikis.php')
system(f'sudo rm /srv/mediawiki/config/ExtensionMessageFiles-{version}.php')
system(f'sudo rm -rf /srv/mediawiki/cache/{version}')
system(f'sudo rm -rf /srv/mediawiki/femiwiki-deploy/{version}')
system(f'sudo rm -rf /srv/mediawiki/{version}')
system(f'sudo rm -rf /srv/mediawiki-staging/{version}')
