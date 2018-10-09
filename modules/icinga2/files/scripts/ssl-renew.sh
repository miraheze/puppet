#!/bin/bash

if [ -z "$SERVICEATTEMPT" ]
then
  SERVICEATTEMPT=$1
fi

if [ -z "$SERVICESTATE" ]
then
  SERVICESTATE=$2
fi

if [ -z "$SERVICESTATETYPE" ]
then
  SERVICESTATETYPE=$3
fi

if [ -z "$SERVICEDESC" ]
then
  SERVICEDESC=$4
fi

curl -X POST -H "Content-Type: application/json" -d '{
  "SERVICEATTEMPT": "'${SERVICEATTEMPT}'",
  "SERVICESTATE": "'${SERVICESTATE}'",
  "SERVICESTATETYPE": "'${SERVICESTATETYPE}'",
  "SERVICEDESC": "'${SERVICEDESC}'"
}' http://185.52.1.75:5000/renew >> /var/log/icinga2/ssl-let.log 2>&1
