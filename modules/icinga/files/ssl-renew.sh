#!/bin/sh

SERVICEDISPLAYNAME="$1"
SERVICEDESC="$2"
SERVICESTATE="$3"

#/usr/bin/ssh -t -i /home/icinga/id_rsa2 nagiosre@mw1.miraheze.org  "/var/lib/nagios/ssl-acme -u ${SERVICEDISPLAYNAME} -d \"${SERVICEDESC}\" -s ${SERVICESTATE}"

/usr/bin/ssh -t -i /var/lib/nagios/id_rsa2 nagiosre@mw1.miraheze.org  "/var/lib/nagios/ssl-acme \"${SERVICEDISPLAYNAME}\" \"${SERVICEDESC}\" \"${SERVICESTATE}\"" > /var/log/icinga/ssl-let.log
