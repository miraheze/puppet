#!/bin/sh

/usr/bin/ssh -t -i  /var/lib/nagios/id_rsa2 nagiosre@mw1.miraheze.org  "/var/lib/nagios/ssl-acme -a ${SERVICEATTEMPT} -s ${SERVICESTATE} -t ${SERVICESTATETYPE} -u ${SERVICEDESC}" >> /var/log/icinga2/ssl-let.log 2>&1
