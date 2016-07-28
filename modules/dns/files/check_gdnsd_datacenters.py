#! /usr/bin/python
import sys, urllib, json

depooled_datacenters = []

request = urllib.urlopen('http://127.0.0.1:3506/json')

json = json.load(request)

for service in json['services']:
        if service['real_state'] == 'DOWN':
                depooled_datacenters.append(service['service'])

if len(depooled_datacenters) == 0:
        print "OK - all datacenters are online"
        sys.exit(0)
elif len(depooled_datacenters) == 1:
        print "CRITICAL - 1 datacenter is down: %s" % ''.join(depooled_datacenters)
        sys.exit(2)
elif len(depooled_datacenters) > 1:
        print "CRITICAL - %s datacenters are down: %s" % (len(depooled_datacenters), ', '.join(depooled_datacenters))
