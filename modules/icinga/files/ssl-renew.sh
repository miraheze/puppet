#!/bin/bash

ssh -i /home/nagios/.ssh/id_rsa nagios@mw1.miraheze.org  '/var/lib/nagios/ssl-acme'
