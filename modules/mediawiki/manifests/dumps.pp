# class: mediawiki::dumps
#
# Cron jobs of select wiki dumps
class mediawiki::dumps {
    package { 'zip':
        ensure => present,
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

    cron { 'Export cpiwiki xml dump weekly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki cpiwiki --logs --full --uploads > /mnt/mediawiki-static/dumps/cpiwiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '22', '29'],
    }

    cron { 'Export cpiwiki images weekly':
        ensure   => present,
        command  => '/usr/bin/zip -r /mnt/mediawiki-static/dumps/cpiwiki.zip /mnt/mediawiki-static/cpiwiki/',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '22', '29'],
    }

    cron { 'Export icmscholarswiki xml dump every two weeks':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki icmscholarswiki --logs --full > /home/reception/dumps/icmscholarswiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => [ '15', '30'],
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

    cron { 'Export mikrodevwiki xml dump weekly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki mikrodevwiki --logs --full --uploads > /mnt/mediawiki-static/dumps/mikrodevwiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '22', '29'],
    }

    cron { 'Export modularwiki xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki modularwiki --logs --full --uploads > /mnt/mediawiki-static/dumps/modularwiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }
    
        cron { 'Export nenawikiwiki xml dump weekly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki nenawikiwiki --logs --full --uploads > /mnt/mediawiki-static/dumps/amaninfowiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '22', '29'],
    }

    cron { 'Export nenawikiwiki images weekly':
        ensure   => present,
        command  => '/usr/bin/zip -r /mnt/mediawiki-static/dumps/nenawikiwiki.zip /mnt/mediawiki-static/nenawikiwiki/',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '22', '29'],
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

    cron { 'Export scruffywiki xml dump weekly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki scruffywiki --logs --full > /home/reception/dumps/scruffywiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export speleowiki xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki speleowiki --logs --full --uploads > /mnt/mediawiki-static/dumps/speleowiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1'
    }

    cron { 'Export sqlserverwiki xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki sqlserverwiki --logs --full --uploads > /mnt/mediawiki-static/dumps/sqlserverwiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1'
    }

    cron { 'Export sterbalssundrystudieswiki xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki sterbalssundrystudieswiki --logs --full > /mnt/mediawiki-static/dumps/sterbalssundrystudieswiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export sterbalfamilyrecipeswiki xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki sterbalfamilyrecipeswiki --logs --full > /mnt/mediawiki-static/dumps/sterbalfamilyrecipeswiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
}
