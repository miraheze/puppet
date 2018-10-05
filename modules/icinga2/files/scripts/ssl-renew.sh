#!/bin/sh

curl -X POST -H "Content-Type: application/json" -d '{
  "SERVICEATTEMPT": "${SERVICEATTEMPT}",
  "SERVICESTATE": "${SERVICESTATE}",
  "SERVICESTATETYPE": "${SERVICESTATETYPE}",
  "SERVICEDESC": "${SERVICEDESC}"
}' http://185.52.1.75:5000/renew >> /var/log/icinga2/ssl-let.log 2>&1
