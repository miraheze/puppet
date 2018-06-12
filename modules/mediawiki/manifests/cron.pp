# class: mediawiki::cron
#
# Used for CORE crons which should be ran on every MediaWiki server.
class mediawiki::cron {
    cron { 'update_database_lists':
        ensure  => present,
        command => '/usr/bin/php /srv/mediawiki/w/extensions/CreateWiki/maintenance/DBListGenerator.php --wiki metawiki',
        user    => 'www-data',
        minute  => '*',
        hour    => '*',
    }

    cron { 'update.php for LocalisationUpdate':
        ensure  => present,
        command => '/usr/bin/php /srv/mediawiki/w/extensions/LocalisationUpdate/update.php --wiki extloadwiki > /var/log/mediawiki/debuglogs/l10nupdate.log',
        user    => 'www-data',
        minute  => '0',
        hour    => '23',
    }

    $php7_2 = hiera('mediawiki::use_php_7_2', false)
    if $php7_2 {
        cron { 'restart_php72fpm':
            ensure  => absent,
            command => '/usr/sbin/service php7.2-fpm restart',
            minute  => '*/10',
        }
    } else {
        cron { 'restart_php70fpm':
            ensure  => absent,
            command => '/usr/sbin/service php7.0-fpm restart',
            minute  => '*/10',
        }
    }
}
