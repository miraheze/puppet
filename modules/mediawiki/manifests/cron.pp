# class: mediawiki::cron
#
# Used for CORE crons which should be ran on every MediaWiki server.
class mediawiki::cron {
    cron { 'update.php for LocalisationUpdate':
        ensure  => present,
        command => '/usr/bin/nice -n 15 /usr/bin/php /srv/mediawiki/w/extensions/LocalisationUpdate/update.php --quiet --wiki=loginwiki > /var/log/mediawiki/debuglogs/l10nupdate.log',
        user    => 'www-data',
        minute  => '0',
        hour    => '23',
    }
}
