#!/bin/bash

set -x

if [ -z "$SERVICESTATE" ]
then
  SERVICESTATE=$1
fi

if [ -z "$SERVICESTATETYPE" ]
then
  SERVICESTATETYPE=$2
fi

if [ -z "$SERVICEDESC" ]
then
  SERVICEDESC=$3
fi

curl -X POST -H 'Content-type: application/json' --data "{
  \"SERVICESTATE\": \"${SERVICESTATE}\",
  \"SERVICESTATETYPE\": \"${SERVICESTATETYPE}\",
  \"SERVICEDESC\": \"${SERVICEDESC}\"
}" http://puppet181.fsslc.wtnet:5000/renew >> /var/log/icinga2/ssl-let.log 2>&1
