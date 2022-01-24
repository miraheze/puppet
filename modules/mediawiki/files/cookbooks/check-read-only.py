#! /usr/bin/python3

from requests import get
from sys import exit
headers = {'host': 'meta.miraheze.org'}
response = get('https://localhost/w/api.php?action=query&meta=siteinfo&formatversion=2&format=json', headers=headers, verify=False).json()
if not response['query']['general']['readonly']:
    print('Site is READ-WRITE')
    exit(0)
else:
    print(response['query']['general']['readonlyreason'])
    exit(1)
