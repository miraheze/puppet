#!/bin/sh
set -eu
export PATH=/usr/sbin:/sbin:/usr/bin:/bin

gateway=$(getent ahostsv4 "$1" | awk '{ print $1; exit }')
shift

if [ -z "$gateway" ]; then
    echo "could not resolve the gateway" >&2
    exit 1
fi

for ip in "$@"; do
    ip route replace "${ip}/32" via "$gateway"
done
