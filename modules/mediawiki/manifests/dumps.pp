# class: mediawiki::dumps
#
# Cron jobs of select wiki dumps
class mediawiki::dumps {
    cron { 'sterbalssundrystudieswiki':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackups.php --wiki sterbalssundrystudieswiki --logs --full > /mnt/mediawiki-static/dumps/sterbalssundrystudieswiki.xml',
        user     => 'www-data',
        minute   => absent,
        hour     => absent,
        month    => absent,
        monthday => 1,
    }
}
