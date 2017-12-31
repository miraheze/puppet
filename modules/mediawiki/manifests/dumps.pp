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
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export cpiwiki images weekly':
        ensure   => present,
        command  => '/usr/bin/zip -r /mnt/mediawiki-static/dumps/cpiwiki.zip /mnt/mediawiki-static/cpiwiki/',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
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
    
    cron { 'Export lexique xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki lexiquewiki --logs --full --uploads > /mnt/mediawiki-static/dumps/lexiquewiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }
    
    cron { 'Export madgendersciencewiki xml dump biweekly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki madgendersciencewiki --logs --full --uploads > /mnt/mediawiki-static/dumps/madgendersciencewiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['15', '30'],
    }

    cron { 'Export mikrodevwiki xml dump weekly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki mikrodevwiki --logs --full --uploads > /mnt/mediawiki-static/dumps/mikrodevwiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export mussmanwissenwiki xml dump biweekly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki mussmanwissenwiki --logs --full --uploads > /mnt/mediawiki-static/dumps/mussmanwissenwiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['15', '30'],
    }
    
    cron { 'Export nenawikiwiki xml dump weekly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki nenawikiwiki --logs --full --uploads > /mnt/mediawiki-static/dumps/nenawikiwiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export nenawikiwiki images weekly':
        ensure   => present,
        command  => '/usr/bin/zip -r /mnt/mediawiki-static/dumps/nenawikiwiki.zip /mnt/mediawiki-static/nenawikiwiki/',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
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
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki scruffywiki --logs --full > /mnt/mediawiki-static/dumps/scruffywiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export scruffywiki images weekly':
        ensure   => present,
        command  => '/usr/bin/zip -r /mnt/mediawiki-static/dumps/scruffywiki.zip /mnt/mediawiki-static/scruffywiki/',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export sdiywiki xml dump weekly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki sdiywiki --logs --full --uploads > /mnt/mediawiki-static/dumps/sdiywiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export sdiywiki images weekly':
        ensure   => present,
        command  => '/usr/bin/zip -r /mnt/mediawiki-static/dumps/sdiywiki.zip /mnt/mediawiki-static/sdiywiki/',
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

    cron { 'Export sterbalfamilyrecipeswiki xml dump weekly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki sterbalfamilyrecipeswiki --logs --full > /mnt/mediawiki-static/dumps/sterbalfamilyrecipeswiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export sterbalfamilyrecipeswiki images weekly':
        ensure   => present,
        command  => '/usr/bin/zip -r /mnt/mediawiki-static/dumps/sterbalfamilyrecipeswiki.zip /mnt/mediawiki-static/sterbalfamilyrecipeswiki/',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export tmewiki xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki tmewiki --logs --full > /mnt/mediawiki-static/dumps/tmewiki.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }

    cron { 'Export worlduniversityandschool xml dump monthly':
        ensure   => present,
        command  => '/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki worlduniversityandschoolwiki --logs --full --uploads > /mnt/mediawiki-static/dumps/worlduniversityandschool.xml',
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1'
    }
 }
