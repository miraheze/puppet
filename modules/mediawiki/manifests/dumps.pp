# class: mediawiki::dumps
#
# Cron jobs of select wiki dumps
class mediawiki::dumps {
    cron { 'Export sterbalssundrystudieswiki xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki sterbalssundrystudieswiki --logs --full > /mnt/mediawiki-static/dumps/sterbalssundrystudieswiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }

    cron { 'Export amaninfowiki xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki amaninfowiki --logs --full --uploads > /mnt/mediawiki-static/dumps/amaninfowiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['15', '30'],
    }

    cron { 'Export amaninfowiki images monthly':
        ensure   => present,
        command  => '/usr/bin/zip -r /mnt/mediawiki-static/dumps/amaninfowiki.zip /mnt/mediawiki-static/amaninfowiki/',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['15', '30'],
    }

    cron { 'Export jokowiki xml dump montly ':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki jokowiki --logs --full > /mnt/mediawiki-static/dumps/jokowiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }
     cron { 'Export nissanecuwiki xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki nissanecuwiki --logs --full --uploads > /mnt/mediawiki-static/dumps/nissanecuwiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['15', '30'],
        }
}
