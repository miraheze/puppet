#!/bin/bash
#
# Miraheze Staff 2018
set -e
set -u

if [ ! -d /srv/mediawiki/services/ ]; then
        cd /srv/mediawiki/ && GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -i /var/lib/nagios/id_rsa -F /dev/null' git clone git@github.com:miraheze/services.git && cd /srv/mediawiki/services/ && git config --local core.sshCommand "ssh -o StrictHostKeyChecking=no -i /var/lib/nagios/id_rsa -F /dev/null"
else
        cd /srv/mediawiki/services/ && git config --local core.sshCommand "ssh -o StrictHostKeyChecking=no -i /var/lib/nagios/id_rsa -F /dev/null" && git reset --hard origin/master && git pull
fi

git -C /srv/mediawiki/services/ config user.email "noreply@miraheze.org"

git -C /srv/mediawiki/services/ config user.name "MirahezeSSLBot"

/usr/bin/php /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/addWikiToServices.php --wiki=metawiki

git -C /srv/mediawiki/services/ add -A --all

git -C /srv/mediawiki/services/ commit -m "BOT: Updating services config for wikis"

git -C /srv/mediawiki/services/ push origin master

exit 0
