#! /usr/bin/python3
import codecs
import json
import sys
import urllib.request

depooled_datacenters = []

request = urllib.request.urlopen('http://127.0.0.1:3506/json')

reader = codecs.getreader("utf-8")
json = json.load(reader(request))

for service in json['services']:
    if service['real_state'] == 'DOWN':
        depooled_datacenters.append(service['service'])

if len(depooled_datacenters) == 0:
    print("OK - all datacenters are online")
    sys.exit(0)
elif len(depooled_datacenters) == 1:
    print("CRITICAL - 1 datacenter is down: %s" % ''.join(depooled_datacenters))
    sys.exit(2)
elif len(depooled_datacenters) > 1:
    print("CRITICAL - %s datacenters are down: %s" % (len(depooled_datacenters), ', '.join(depooled_datacenters)))
    sys.exit(2)
