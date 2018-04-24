#!/bin/sh

/usr/bin/python /etc/icinga2/ssl-phabricator.py -s "$SERVICESTATE" -t "$SERVICESTATETYPE" -a "$SERVICEATTEMPT" -H "$HOSTADDRESS" -D "$SERVICEDESC" -m "$SERVICEOUTPUT"
