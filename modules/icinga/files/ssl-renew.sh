#!/bin/bash

SERVICEDISPLAYNAME="$1"
SERVICEDESC="$2"
SERVICESTATE="$3"

ssh -t -i /home/nagiosre/.ssh/id_rsa nagiosre@mw1.miraheze.org  "/var/lib/nagios/ssl-acme ${SERVICEDISPLAYNAME} ${SERVICEDESC} ${SERVICESTATE}"
