# class: mediawiki::cron
#
# Used for CORE crons which should be ran on every MediaWiki server.
class mediawiki::cron {
    # HACK BAD BAD HACK
    cron { 'hhvm_hack_restart':
        ensure  => present,
        command => "/usr/sbin/service hhvm restart",
        user    => 'root',
        hour    => '*/2',
    }

    cron { 'update_database_lists':
        ensure  => present,
        command => '/usr/bin/php /srv/mediawiki/w/extensions/CreateWiki/DBListGenerator.php --wiki metawiki',
        user    => 'www-data',
        minute  => '*',
        hour    => '*',
    }
}
