alias mwdeployconf-all="sudo salt-ssh -E 'mw.*|test.*|jobrunner.*' cmd.run 'sudo -u www-data git -C /srv/mediawiki/config pull'"
