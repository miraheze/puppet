#! /usr/bin/python3

from requests import get
import sys
headers = {'host': 'meta.miraheze.org'}
response = get('https://localhost/w/api.php?action=query&meta=siteinfo&formatversion=2&format=json', headers=headers, verify=False).json()
if not response['query']['general']['readonly']:
    print('Site is READ-WRITE')
    sys.exit(0)
else:
    print(response['query']['general']['readonlyreason'])
    sys.exit(1)
