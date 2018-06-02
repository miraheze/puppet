#!/bin/sh

SERVICEDISPLAYNAME="$1"
SERVICESTATE="$2"

/usr/bin/ssh -t -i /var/lib/nagios/id_rsa2 nagiosre@mw1.miraheze.org  "/var/lib/nagios/ssl-acme -s \"${SERVICESTATE}\" -u \"${SERVICEDISPLAYNAME}\"" >> /var/log/icinga/ssl-let.log
