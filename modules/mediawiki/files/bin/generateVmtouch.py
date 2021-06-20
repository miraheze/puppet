#! /usr/bin/python3

import os.path
from glob import glob

files = [
    '/srv/mediawiki/cache/databases.json'
]

l10nLangs = [
    'de',
    'en',
    'es',
    'it',
    'ja',
    'ko',
    'nl',
    'zh',
    'zh-cn',
    'zh-tw'
]

globFiles = [
    '/etc/ssl/certs',
    '/etc/ssl/localcerts',
    '/srv/mediawiki/cache/*wiki.json',
    '/srv/mediawiki/w/extensions/*/extension.json',
    '/srv/mediawiki/w/skins/*/skin.json',
    '/usr/share/ca-certificates/mozilla'
]

for globFile in globFiles:
    for file in glob(globFile):
        if os.path.isfile(file):
            files.append(file)
        elif os.path.isdir(file):
            files.append(file)

for lang in l10nLangs:
    files.append("/srv/mediawiki/cache/l10n/l10n_cache-{}.cdb".format(lang))

with open('/etc/vmtouch-files.list', mode='wt') as filesList:
    filesList.write('\n'.join(files))
    filesList.write('\n')

# After writing to file we restart the service to pickup the changes.
os.system( 'sudo service vmtouch restart' )
