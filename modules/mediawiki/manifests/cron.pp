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

    if $::fqdn == 'mw1.miraheze.org' {
        cron { 'generate_services':
            ensure  => present,
            command => '/usr/bin/php /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/addWikiToServices.php --wiki=metawiki ** /bin/bash /usr/local/bin/pushServices.sh',
            user    => 'www-data',
            minute  => '*/10',
            hour    => '*',
        }
    }

    cron { 'update.php for LocalisationUpdate':
        ensure  => present,
        command => '/usr/bin/php /srv/mediawiki/w/extensions/LocalisationUpdate/update.php --wiki loginwiki > /var/log/mediawiki/debuglogs/l10nupdate.log',
        user    => 'www-data',
        minute  => '0',
        hour    => '23',
    }
}
