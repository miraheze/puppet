#!/bin/bash

SERVICEDISPLAYNAME="$1"
SERVICEDESC="$2"
SERVICESTATE="$3"

ssh -t -i /var/lib/nagios/id_rsa2 nagiosre@mw1.miraheze.org  "/var/lib/nagios/ssl-acme ${SERVICEDISPLAYNAME} ${SERVICEDESC} ${SERVICESTATE}"
