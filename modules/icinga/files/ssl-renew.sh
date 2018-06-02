#!/bin/sh

SERVICEDISPLAYNAME="$1"
SERVICESTATE="$2"
SERVICESTATETYPE="$3"
SERVICEATTEMPT="$4"

/usr/bin/ssh -t -i  /var/lib/nagios/id_rsa2 nagiosre@mw1.miraheze.org  "/var/lib/nagios/ssl-acme -a ${SERVICEATTEMPT} -s ${SERVICESTATE} -t {SERVICESTATETYPE} -u ${SERVICEDISPLAYNAME}" >> /var/log/icinga/ssl-let.log 2>&1
