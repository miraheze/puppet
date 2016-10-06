# class: mediawiki::dumps
#
# Cron jobs of select wiki dumps
class mediawiki::dumps {
    cron { 'Export sterbalssundrystudieswiki xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackups.php --wiki sterbalssundrystudieswiki --logs --full > /mnt/mediawiki-static/dumps/sterbalssundrystudieswiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => 1,
    }
}
