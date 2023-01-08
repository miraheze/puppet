#!/bin/bash

/usr/bin/flock -w 10 /tmp/matomo_file_lock /usr/bin/php /srv/matomo/console core:archive --url=https://matomo.miraheze.org/ > /srv/matomo-archive.log 2>&1
