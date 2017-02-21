#!/bin/bash

while read line
do
	wiki=`/bin/echo $line | /usr/bin/cut -d "|" -f1`
	if ! /bin/grep -q "$wiki" /srv/mediawiki/dblist/private.dblist; then
		/bin/echo ${wiki%????}
	fi
done < $1
