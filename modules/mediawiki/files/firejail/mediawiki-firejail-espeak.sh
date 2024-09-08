#!/bin/sh
exec /usr/bin/firejail --quiet --profile=/etc/firejail/mediawiki-converters.profile /usr/bin/espeak "$@"
