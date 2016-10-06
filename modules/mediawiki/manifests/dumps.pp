# class: mediawiki::dumps
#
# Cron jobs of select wiki dumps
class mediawiki::cron {
    cron { 'update_database_lists':
        ensure   => present,
        command  => '/usr/bin/php /srv/mediawiki/w/maintenance/dumpBackups.php --wiki sterbalssundrystudieswiki --logs --full',
        user     => 'www-data',
        minute   => absent,
        hour     => absent,
        month    => absent,
        monthday => 1,
    }
}
