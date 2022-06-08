#! /usr/bin/python3

import os
import requests
canary = 'mwtask111'
serverlist = ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122']


def check_up(server: str) -> bool:
    headers = {'X-Miraheze-Debug': f'{server}.miraheze.org'}
    req = requests.get('https://meta.miraheze.org/w/api.php?action=query&meta=siteinfo&formatversion=2&format=json', headers=headers)
    if req.status_code == 200 and 'miraheze' in req.text and server in req.headers['X-Served-By']:
        return True
    return False


def check_ro(server: str) -> bool:
    headers = {'X-Miraheze-Debug': f'{server}.miraheze.org'}
    req = requests.get('https://meta.miraheze.org/w/api.php?action=query&meta=siteinfo&formatversion=2&format=json', headers=headers)
    response = req.json()
    if response['query']['general']['readonly']:
        return True
    return False


print('Welcome to the MediaWiki Upgrade tool!')
input('Please confirm you are running this script on the canary server: (press enter)')
input('MediaWiki -> RO - Running puppet to sync config')
os.system('sudo puppet agent -tv')
print('Config deployed')
print('Checking RO on Canary Server')
if not check_ro(canary):
    input('Stopping deploy - RO check failed - Press enter to resume')
for server in serverlist:
    print(f'Confirming RO on {server}')
    if not check_ro(server):
        input(f'RO check failed on {server} - Press enter to resume')
print('Starting staging update')
input('Press enter when branch updated in puppet: ')
os.system('sudo -u www-data rm -rf /srv/mediawiki-staging/w')
os.system('sudo puppet agent -tv')
print('Will now check mediawiki branch')
os.system('git -C /srv/mediawiki-staging/w rev-parse --abbrev-ref HEAD')
input('Confirm: ')
print('Will now deploy to canary server')
os.system(f'deploy-mediawiki --world --l10n --force --ignore-time --servers={canary}')
if check_up(canary) and check_ro(canary):
    print('Canary deploy done')
else:
    print('Canary is not online')
input('Press enter to rollout: ')
for server in serverlist:
    print(f'Will now deploy to {server}')
    os.system(f'deploy-mediawiki --world --l10n --force --ignore-time --servers={server}')
    if check_up(server) and check_ro(server):
        print(f'{server} deploy done')
    else:
        input(f'{server} is not online - Proceed? ')
print('Deployment done')
input('Please merge RW change and press enter: ')
print('Running puppet')
os.system('sudo puppet agent -tv')
print('Deployment done')
