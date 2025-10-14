#!/bin/bash
set -euo pipefail
# Daily systemd timer to restart php-fpm if the free opcache is below a certain level.

# Service name
SERVICE="$1"
# Minimum opcache free MB.
MIN_OPCACHE_FREE="$2"
OPCACHE_FREE=$(php8adm /opcache-info | jq .memory_usage.free_memory/1024/1024 2>&1)
OPCACHE_FREE_MB=${OPCACHE_FREE%.*}

if [ "$MIN_OPCACHE_FREE" -ge "$OPCACHE_FREE_MB" ]; then
    echo "Restarting ${SERVICE}: free opcache $OPCACHE_FREE_MB MB"
    "/usr/local/sbin/restart-$SERVICE"
    exit 0
else
    echo "NOT restarting ${SERVICE}: free opcache $OPCACHE_FREE_MB MB"
fi

APCU_FRAGMENTATION_LIMIT='95' # percentage
APCU_FRAGMENTATION=$(php8adm /apcu-frag |jq .fragmentation 2>&1)

if [ "${APCU_FRAGMENTATION%.*}" -ge "$APCU_FRAGMENTATION_LIMIT" ]; then
    echo "Fragmentation is at ${APCU_FRAGMENTATION%.*}%, freeing APCu cache"
    /usr/local/bin/php8adm /apcu-free
else
    echo "Fragmentation is at ${APCU_FRAGMENTATION%.*}%, nothing to do here"
fi

MAX_CACHED_KEYS=$(($(php8adm /opcache-info |jq .opcache_statistics.max_cached_keys  2>&1)-5000))
NUM_CACHED_KEYS=$(php8adm /opcache-info |jq .opcache_statistics.num_cached_keys  2>&1)

if [ "$NUM_CACHED_KEYS" -ge "$MAX_CACHED_KEYS" ]; then
    echo "Restarting ${SERVICE}: Number of cached keys $NUM_CACHED_KEYS is over the $MAX_CACHED_KEYS limit"
    "/usr/local/sbin/restart-$SERVICE"
    exit 0
else
    echo "NOT restarting ${SERVICE}: Number of cached keys $NUM_CACHED_KEYS"
fi
