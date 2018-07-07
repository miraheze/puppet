# class: mediawiki::dumps
#
# Cron jobs of select wiki dumps
class mediawiki::dumps {
    package { 'zip':
        ensure => present,
    }
    
    $swift_password = hiera('passwords::mediawiki::swift::admin')
    
    cron { 'Export aesbasewiki xml dump montly ':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki aesbasewiki --logs --full > /srv/files/dumps/aesbasewiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps aesbasewiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }

    cron { 'Export amaninfowiki xml dump monthly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki amaninfowiki --logs --full --uploads > /srv/files/dumps/amaninfowiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps amaninfowiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['15', '30'],
    }

    cron { 'Export amaninfowiki images monthly':
        ensure   => present,
        command  => "mkdir -p /srv/files/dumps/amaninfowiki && cd /srv/files/dumps/amaninfowiki/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift download amaninfowiki-mw && /usr/bin/zip -r /srv/files/dumps/amaninfowiki.zip /srv/files/dumps/amaninfowiki/ && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps amaninfowiki.zip",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['15', '30'],
    }

    cron { 'Export cpiwiki xml dump weekly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki cpiwiki --logs --full --uploads > /srv/files/dumps/cpiwiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps cpiwiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export cpiwiki images weekly':
        ensure   => present,
        command  => "mkdir -p /srv/files/dumps/cpiwiki && cd /srv/files/dumps/cpiwiki/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift download cpiwiki-mw && /usr/bin/zip -r /srv/files/dumps/cpiwiki.zip /srv/files/dumps/cpiwiki/ && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps cpiwiki.zip",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export jokowiki xml dump montly ':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki jokowiki --logs --full > /srv/files/dumps/jokowiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps jokowiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }
    
    cron { 'Export lexique xml dump monthly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki lexiquewiki --logs --full --uploads > /srv/files/dumps/lexiquewiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps lexiquewiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }
    
    cron { 'Export madgendersciencewiki xml dump biweekly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki madgendersciencewiki --logs --full --uploads > /srv/files/dumps/madgendersciencewiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps madgendersciencewiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['15', '30'],
    }

    cron { 'Export mikrodevwiki xml dump weekly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki mikrodevwiki --logs --full --uploads > /srv/files/dumps/mikrodevwiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps mikrodevwiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export mussmanwissenwiki xml dump biweekly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki mussmanwissenwiki --logs --full --uploads > /srv/files/dumps/mussmanwissenwiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps mussmanwissenwiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['15', '30'],
    }
    
    cron { 'Export nenawikiwiki xml dump weekly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki nenawikiwiki --logs --full --uploads > /srv/files/dumps/nenawikiwiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps nenawikiwiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export nenawikiwiki images weekly':
        ensure   => present,
        command  => "mkdir -p /srv/files/dumps/nenawikiwiki && cd /srv/files/dumps/nenawikiwiki/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift download nenawikiwiki-mw && /usr/bin/zip -r /srv/files/dumps/nenawikiwiki.zip /srv/files/dumps/cpiwiki/ && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps nenawikiwiki.zip",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export nissanecuwiki xml dump monthly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki nissanecuwiki --logs --full --uploads > /srv/files/dumps/nissanecuwiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps nissanecuwiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['15', '30'],
    }

    cron { 'Export nonbinarywiki xml dump montly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki nonbinarywiki --logs --full --uploads > /srv/files/dumps/nonbinarywiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps nonbinarywiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }
    
    cron { 'Export renaissancewiki xml dump monthly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki renaissancewiki --logs --full --uploads > /srv/files/dumps/renaissancewiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps renaissancewiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }

    cron { 'Export scruffywiki xml dump weekly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki scruffywiki --logs --full > /srv/files/dumps/scruffywiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps scruffywiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export scruffywiki images weekly':
        ensure   => present,
        command  => "mkdir -p /srv/files/dumps/scruffywiki && cd /srv/files/dumps/scruffywiki/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift download scruffywiki-mw && /usr/bin/zip -r /srv/files/dumps/scruffywiki.zip /srv/files/dumps/cpiwiki/ && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps scruffywiki.zip",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export sdiywiki xml dump weekly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki sdiywiki --logs --full --uploads > /srv/files/dumps/sdiywiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps sdiywiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export sdiywiki images weekly':
        ensure   => present,
        command  => "mkdir -p /srv/files/dumps/sdiywiki && cd /srv/files/dumps/sdiywiki/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift download sdiywiki-mw && /usr/bin/zip -r /srv/files/dumps/sdiywiki.zip /srv/files/dumps/cpiwiki/ && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps sdiywiki.zip",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export speleowiki xml dump monthly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki speleowiki --logs --full --uploads > /srv/files/dumps/speleowiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps speleowiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1'
    }

    cron { 'Export sqlserverwiki xml dump monthly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki sqlserverwiki --logs --full --uploads > /srv/files/dumps/sqlserverwiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps sqlserverwiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1'
    }

    cron { 'Export sterbalssundrystudieswiki xml dump monthly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki sterbalssundrystudieswiki --logs --full > /srv/files/dumps/sterbalssundrystudieswiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps sterbalssundrystudieswiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }

    cron { 'Export sterbalfamilyrecipeswiki xml dump weekly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki sterbalfamilyrecipeswiki --logs --full > /srv/files/dumps/sterbalfamilyrecipeswiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps sterbalfamilyrecipeswiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export sterbalfamilyrecipeswiki images weekly':
        ensure   => present,
        command  => "mkdir -p /srv/files/dumps/sterbalfamilyrecipeswiki && cd /srv/files/dumps/sterbalfamilyrecipeswiki/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift download sterbalfamilyrecipeswiki-mw && /usr/bin/zip -r /srv/files/dumps/sterbalfamilyrecipeswiki.zip /srv/files/dumps/sterbalfamilyrecipeswiki/ && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps sterbalfamilyrecipeswiki.zip",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export templatewiki xml dump weekly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki templatewiki --logs --full > /srv/files/dumps/templatewiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps templatewiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => ['1', '8', '15', '22', '29'],
    }
    
    cron { 'Export tmewiki xml dump monthly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki tmewiki --logs --full > /srv/files/dumps/tmewiki.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps tmewiki.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1',
    }

    cron { 'Export worlduniversityandschool xml dump monthly':
        ensure   => present,
        command  => "/usr/bin/nice -n19 /usr/bin/php /srv/mediawiki/w/maintenance/dumpBackup.php --wiki worlduniversityandschoolwiki --logs --full --uploads > /srv/files/dumps/worlduniversityandschool.xml && cd /srv/files/dumps/ && ST_AUTH='http://81.4.124.61:8080/auth/v1.0' ST_USER=admin:admin ST_KEY=${swift_password} swift upload dumps worlduniversityandschool.xml",
        user     => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => '1'
    }
}
