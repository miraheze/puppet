# class: mediawiki::extensionupdate
#
# Cron jobs of different Miraheze extensions to be updated
class mediawiki::extensionupdate {
    cron { 'Update CreateWiki':
        ensure   => present,
        command  => '/usr/bin/nice -n15 git -C /srv/mediawiki/w/extensions/CreateWiki config user.email "noreply@miraheze.org" && git -C /srv/mediawiki/w/extensions/CreateWiki config user.name "MirahezeGitHubBot" && cd /srv/mediawiki/w/extensions/CreateWiki && git -C /srv/mediawiki/w/extensions/CreateWiki pull && git -C /srv/mediawiki/w/extensions/CreateWiki commit -m "Bot: Update CreateWiki" && git -C /srv/mediawiki/w/extensions/CreateWiki push origin master',
        user     => 'www-data',
        minute   => '0',
        hour     => '10',
        month    => '*',
        weekday  => '1',
    }
    cron { 'Update ManageWiki':
        ensure   => present,
        command  => '/usr/bin/nice -n15 git -C /srv/mediawiki/w/extensions/ManageWiki config user.email "noreply@miraheze.org" && git -C /srv/mediawiki/w/extensions/ManageWiki config user.name "MirahezeGitHubBot" && cd /srv/mediawiki/w/extensions/ManageWiki && git -C /srv/mediawiki/w/extensions/ManageWiki pull && git -C /srv/mediawiki/w/extensions/ManageWiki commit -m "Bot: Update ManageWiki" && git -C /srv/mediawiki/w/extensions/ManageWiki push origin master',
        user     => 'www-data',
        minute   => '0',
        hour     => '10',
        month    => '*',
		weekday  => '1',
    }
    cron { 'Update WikiDiscover':
        ensure   => present,
        command  => '/usr/bin/nice -n15 git -C /srv/mediawiki/w/extensions/WikiDiscover config user.email "noreply@miraheze.org" && git -C /srv/mediawiki/w/extensions/WikiDiscover config user.name "MirahezeGitHubBot" && cd /srv/mediawiki/w/extensions/WikiDiscover && git -C /srv/mediawiki/w/extensions/WikiDiscover pull && git -C /srv/mediawiki/w/extensions/WikiDiscover commit -m "Bot: Update WikiDiscover" && git -C /srv/mediawiki/w/extensions/WikiDiscover push origin master',
        user     => 'www-data',
        minute   => '0',
        hour     => '10',
        month    => '*',
		weekday  => '1',
    }
}