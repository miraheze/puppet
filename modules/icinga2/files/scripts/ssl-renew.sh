#!/bin/bash

curl -X POST -H "Content-Type: application/json" -d '{
  "SERVICEATTEMPT": "'${1}'",
  "SERVICESTATE": "'${2}'",
  "SERVICESTATETYPE": "'${3}'",
  "SERVICEDESC": "'${4}'"
}' http://185.52.1.75:5000/renew >> /var/log/icinga2/ssl-let.log 2>&1
