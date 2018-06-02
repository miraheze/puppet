#!/bin/bash

ssh -i /home/nagiosre/.ssh/id_rsa nagiosre@mw1.miraheze.org  '/var/lib/nagios/ssl-acme'
