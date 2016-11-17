# class: mediawiki::cron
#
# Used for CORE crons which should be ran on every MediaWiki server.
class mediawiki::cron {
    cron { 'update_database_lists':
        ensure  => present,
        command => '/usr/bin/php /srv/mediawiki/w/extensions/CreateWiki/DBListGenerator.php --wiki metawiki',
        user    => 'www-data',
        minute  => '*',
        hour    => '*',
    }
    cron { 'update.php for LocalisationUpdate':
        ensure  => present,
        command => '/usr/bin/php /srv/mediawiki/w/extensions/LocalisationUpdate/update.php --wiki extloadwiki /var/log/mediawiki/debuglogs/l10nupdate.log',
        user    => 'www-data',
        minute  => '0',
        hour    => '23',
    }
}
