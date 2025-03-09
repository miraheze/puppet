#!/bin/sh
exec /usr/bin/firejail --profile=/etc/firejail/mediawiki-converters.profile /usr/bin/rsvg-convert "$@"
