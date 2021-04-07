# class: mediawiki::jobrunner
#
# Crons which should be ran on a jobrunner selected machine only.
class mediawiki::jobrunner {
    require_package('python3-xmltodict')

    git::clone { 'JobRunner':
        directory => '/srv/jobrunner',
        origin    => 'https://github.com/miraheze/jobrunner-service',
    }

    $redis_password = lookup('passwords::redis::master')

    file { '/srv/jobrunner/jobrunner.json':
        ensure  => present,
        content => template('mediawiki/jobrunner.json.erb'),
        notify  => Service['jobrunner'],
        require => Git::Clone['JobRunner'],
    }

    systemd::service { 'jobrunner':
        ensure  => present,
        content => systemd_template('jobrunner'),
        restart => true,
    }

    systemd::service { 'jobchron':
        ensure  => present,
        content => systemd_template('jobchron'),
        restart => true,
    }

    if lookup('mediawiki::jobrunner::cron', {'default_value' => false}) {
        cron { 'purge_checkuser':
            ensure  => present,
            command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/w/cache/databases.json /srv/mediawiki/w/extensions/CheckUser/maintenance/purgeOldData.php >> /var/log/mediawiki/cron/purge_checkuser.log',
            user    => 'www-data',
            minute  => '5',
            hour    => '6',
        }

        cron { 'purge_abusefilter':
            ensure  => present,
            command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/w/cache/databases.json /srv/mediawiki/w/extensions/AbuseFilter/maintenance/purgeOldLogIPData.php >> /var/log/mediawiki/cron/purge_abusefilter.log',
            user    => 'www-data',
            minute  => '5',
            hour    => '18',
        }

        cron { 'managewikis':
            ensure  => present,
            command => '/usr/bin/php /srv/mediawiki/w/extensions/CreateWiki/maintenance/manageInactiveWikis.php --wiki loginwiki --write >> /var/log/mediawiki/cron/managewikis.log',
            user    => 'www-data',
            minute  => '5',
            hour    => '12',
        }

        cron { 'update rottenlinks on all wikis':
            ensure  => present,
            command => '/usr/local/bin/fileLockScript.sh /tmp/rotten_links_file_lock "/usr/bin/nice -19 /usr/local/bin/foreachwikiindblist /srv/mediawiki/w/cache/databases.json /srv/mediawiki/w/extensions/RottenLinks/maintenance/updateExternalLinks.php"',
            user    => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            monthday => [ '14', '28' ],
        }

        cron { 'generate sitemaps for all wikis':
            ensure  => present,
            command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/w/cache/databases.json /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/generateMirahezeSitemap.php',
            user    => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            weekday => [ '6' ],
        }

        cron { 'generate sitemap index':
            ensure  => present,
            command => '/usr/bin/python3 /srv/mediawiki/w/extensions/MirahezeMagic/py/generateSitemapIndex.py',
            user    => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            weekday => [ '7' ],
        }

        cron { 'update_statistics':
            ensure   => present,
            command  => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/w/cache/databases.json /srv/mediawiki/w/maintenance/initSiteStats.php --update --active > /dev/null',
            user     => 'www-data',
            minute   => '0',
            hour     => '5',
            monthday => [ '1', '15' ],
        }

        cron { 'update_sites':
            ensure   => present,
            command  => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/w/cache/databases.json /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/populateWikibaseSitesTable.php > /dev/null',
            user     => 'www-data',
            minute   => '0',
            hour     => '5',
            monthday => [ '5', '20' ],
        }

        cron { 'clean_gu_cache':
            ensure   => present,
            command  => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/w/cache/databases.json /srv/mediawiki/w/extensions/GlobalUsage/maintenance/refreshGlobalimagelinks.php --pages=existing,nonexisting > /dev/null',
            user     => 'www-data',
            minute   => '0',
            hour     => '5',
            monthday => [ '6', '21' ],
        }
    }

    file { '/usr/lib/nagios/plugins/check_jobqueue':
        ensure => present,
        source => 'puppet:///modules/mediawiki/jobrunner/check_jobqueue',
        mode   => '0555',
    }

    monitoring::services { 'JobRunner Service':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_jobrunner',
        },
    }

    monitoring::services { 'JobChron Service':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_jobchron',
        },
    }

    monitoring::services { 'JobQueue':
        ensure        => absent,
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_jobqueue',
        },
    }

    sudo::user { 'nrpe_sudo_check_jobqueue':
        user       => 'nagios',
        privileges => [ 'ALL = (www-data) NOPASSWD: /usr/lib/nagios/plugins/check_jobqueue' ],
    }
}
