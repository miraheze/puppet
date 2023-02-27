# === Class mediawiki::jobqueue::runner
#
# Defines a jobrunner process for jobrunner selected machine only.
class mediawiki::jobqueue::runner {
    include mediawiki::jobqueue::shared
    $wiki = lookup('mediawiki::jobqueue::wiki')
    ensure_packages('python3-xmltodict')


    systemd::service { 'jobrunner':
        ensure    => present,
        content   => systemd_template('jobrunner'),
        subscribe => File['/srv/jobrunner/jobrunner.json'],
        restart   => true,
    }

    if lookup('mediawiki::jobqueue::runner::cron', {'default_value' => false}) {
        cron { 'purge_checkuser':
            ensure  => present,
            command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json /srv/mediawiki/w/extensions/CheckUser/maintenance/purgeOldData.php >> /var/log/mediawiki/cron/purge_checkuser.log',
            user    => 'www-data',
            minute  => '5',
            hour    => '6',
        }

        cron { 'purge_abusefilter':
            ensure  => present,
            command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json /srv/mediawiki/w/extensions/AbuseFilter/maintenance/PurgeOldLogIPData.php >> /var/log/mediawiki/cron/purge_abusefilter.log',
            user    => 'www-data',
            minute  => '5',
            hour    => '18',
        }

        cron { 'managewikis':
            ensure  => present,
            command => "/usr/bin/php /srv/mediawiki/w/extensions/CreateWiki/maintenance/manageInactiveWikis.php --wiki ${wiki} --write >> /var/log/mediawiki/cron/managewikis.log",
            user    => 'www-data',
            minute  => '5',
            hour    => '12',
        }

        cron { 'update rottenlinks on all wikis':
            ensure   => present,
            command  => '/usr/local/bin/fileLockScript.sh /tmp/rotten_links_file_lock "/usr/bin/nice -n 15 /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json /srv/mediawiki/w/extensions/RottenLinks/maintenance/updateExternalLinks.php"',
            user     => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            monthday => [ '14', '28' ],
        }

        cron { 'generate sitemaps for all wikis':
            ensure  => present,
            command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/generateMirahezeSitemap.php',
            user    => 'www-data',
            minute  => '0',
            hour    => '0',
            month   => '*',
            weekday => [ '6' ],
        }

        if $wiki == 'loginwiki' {
            $swift_password = lookup('mediawiki::swift_password')
            cron { 'generate sitemap index':
                ensure  => present,
                command => "/usr/bin/python3 /srv/mediawiki/w/extensions/MirahezeMagic/py/generateSitemapIndex.py -A https://swift-lb.miraheze.org/auth/v1.0 -U mw:media -K ${swift_password}",
                user    => 'www-data',
                minute  => '0',
                hour    => '0',
                month   => '*',
                weekday => [ '7' ],
            }

            cron { 'purge_parsercache':
                ensure  => present,
                command => '/usr/bin/php /srv/mediawiki/w/maintenance/purgeParserCache.php --age 864000 --msleep 200 --wiki loginwiki',
                user    => 'www-data',
                special => 'daily',
            }

            cron { 'backups-mediawiki-xml':
                ensure   => present,
                command  => '/usr/local/bin/miraheze-backup backup mediawiki-xml > /var/log/mediawiki-xml-backup.log 2>&1',
                user     => 'root',
                minute   => '0',
                hour     => '1',
                monthday => ['27'],
                month    => ['3', '6', '9', '12']
            }

            monitoring::nrpe { 'Backups MediaWiki XML':
                command  => '/usr/lib/nagios/plugins/check_file_age -w 8640000 -c 11232000 -f /var/log/mediawiki-xml-backup.log',
                docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
                critical => true
            }
        }

        cron { 'update_statistics':
            ensure   => present,
            command  => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json /srv/mediawiki/w/maintenance/initSiteStats.php --update --active > /dev/null',
            user     => 'www-data',
            minute   => '0',
            hour     => '5',
            monthday => [ '1', '15' ],
        }

        cron { 'update_sites':
            ensure   => present,
            command  => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/populateWikibaseSitesTable.php > /dev/null',
            user     => 'www-data',
            minute   => '0',
            hour     => '5',
            monthday => [ '5', '20' ],
        }

        cron { 'clean_gu_cache':
            ensure   => present,
            command  => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json /srv/mediawiki/w/extensions/GlobalUsage/maintenance/refreshGlobalimagelinks.php --pages=existing,nonexisting > /dev/null',
            user     => 'www-data',
            minute   => '0',
            hour     => '5',
            monthday => [ '6', '21' ],
        }
    }

    monitoring::nrpe { 'JobRunner Service':
        command => '/usr/lib/nagios/plugins/check_procs -a redisJobRunnerService -c 1:1',
        docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#JobRunner_Service'
    }
}
