#! /usr/bin/python3
import json
import sys

depooled_datacenters = []

raw = subprocess.check_output(['/usr/bin/gdnsdctl', 'stats'])
json_stats = json.loads(raw)

for service in json_stats['services']:
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
