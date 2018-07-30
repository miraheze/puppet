#!/bin/bash
#
# Miraheze Staff 2018
set -e
set -u

git config --global core.sshCommand "ssh -i /var/lib/nagios/id_rsa -F /dev/null"
if [ ! -d /srv/mediawiki/services/ ]; then
        cd /srv/mediawiki/services/ && git clone git@github.com:miraheze/services.git
else
        cd /srv/mediawiki/services/ && git reset --hard origin/master && git pull
fi
git -C /srv/ssl/ssl/ config user.email "noreply@miraheze.org"
git -C /srv/ssl/ssl/ config user.name "MirahezeSSLBot"
git -C /srv/ssl/ssl add -A --all
git -C /srv/ssl/ssl/ commit -m "Update config for wiki's"
git -C /srv/ssl/ssl/ push origin master

exit 0
