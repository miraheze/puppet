#! /usr/bin/python3

import os.path
from glob import glob

files = [
    '/srv/mediawiki/w/cache/databases.json'
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
    '/srv/mediawiki/w/cache/*wiki.json',
    '/srv/mediawiki/w/extensions/*/extension.json',
    '/srv/mediawiki/w/skins/*/skin.json',
    '/usr/share/ca-certificates/mozilla'
]

for globFile in globFiles:
    globPath = glob(globFile)
    if not globPath:
        files.append(globFile)
    for file in globPath:
        if os.path.isfile(file):
            files.append(file)

for lang in l10nLangs:
    files.append("/srv/mediawiki/w/cache/l10n/l10n_cache-{}.cdb".format(lang))

with open('/etc/vmtouch-files.list', mode='wt') as filesList:
    filesList.write('\n'.join(files))
    filesList.write('\n')

# After writing to file we restart the service to pickup the changes.
os.system( 'service vmtouch restart' )
