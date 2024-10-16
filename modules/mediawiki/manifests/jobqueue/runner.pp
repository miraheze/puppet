# === Class mediawiki::jobqueue::runner
#
# Defines a jobrunner process for jobrunner selected machine only.
class mediawiki::jobqueue::runner (
    String $version,
) {
    if versioncmp($version, '1.40') >= 0 {
        $runner = "/srv/mediawiki/${version}/maintenance/run.php "
    } else {
        $runner = ''
    }

    $wiki = lookup('mediawiki::jobqueue::wiki')

    stdlib::ensure_packages('python3-xmltodict')

    if lookup('mediawiki::use_cpjobqueue', {'default_value' => false}) {
        include mediawiki::jobrunner
        if !defined(Class['mediawiki::jobqueue::shared']) {
            class { 'mediawiki::jobqueue::shared':
                ensure  => absent,
                version => $version,
            }
        }
        systemd::service { 'jobrunner':
            ensure  => absent,
            content => systemd_template('jobrunner'),
        }
    } else {
        if !defined(Class['mediawiki::jobqueue::shared']) {
            class { 'mediawiki::jobqueue::shared':
                version => $version,
            }
        }
        systemd::service { 'jobrunner':
            ensure    => present,
            content   => systemd_template('jobrunner'),
            subscribe => File['/srv/jobrunner/jobrunner.json'],
            restart   => true,
        }

        monitoring::nrpe { 'JobRunner Service':
            command => '/usr/lib/nagios/plugins/check_procs -a redisJobRunnerService -c 1:1',
            docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#JobRunner_Service'
        }
    }

    if lookup('mediawiki::jobqueue::runner::cron', {'default_value' => false}) {
        cron { 'purge_checkuser':
            ensure  => present,
            command => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php ${runner}/srv/mediawiki/${version}/extensions/CheckUser/maintenance/purgeOldData.php >> /var/log/mediawiki/cron/purge_checkuser.log",
            user    => 'www-data',
            minute  => '5',
            hour    => '6',
        }

        cron { 'purge_abusefilter':
            ensure  => present,
            command => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php ${runner}/srv/mediawiki/${version}/extensions/AbuseFilter/maintenance/PurgeOldLogIPData.php >> /var/log/mediawiki/cron/purge_abusefilter.log",
            user    => 'www-data',
            minute  => '5',
            hour    => '18',
        }

        cron { 'managewikis':
            ensure  => present,
            command => "/usr/bin/php ${runner}/srv/mediawiki/${version}/extensions/CreateWiki/maintenance/manageInactiveWikis.php --wiki ${wiki} --write >> /var/log/mediawiki/cron/managewikis.log",
            user    => 'www-data',
            minute  => '5',
            hour    => '12',
        }

        cron { 'update rottenlinks on all wikis':
            ensure   => absent,
            command  => "/usr/local/bin/fileLockScript.sh /tmp/rotten_links_file_lock \"/usr/bin/nice -n 15 /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php ${runner}/srv/mediawiki/${version}/extensions/RottenLinks/maintenance/updateExternalLinks.php\"",
            user     => 'www-data',
            minute   => '0',
            hour     => '0',
            month    => '*',
            monthday => [ '14', '28' ],
        }

        cron { 'generate sitemaps for all wikis':
            ensure  => present,
            command => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php ${runner}/srv/mediawiki/${version}/extensions/MirahezeMagic/maintenance/generateMirahezeSitemap.php",
            user    => 'www-data',
            minute  => '0',
            hour    => '0',
            month   => '*',
            weekday => [ '6' ],
        }

        cron { 'cleanup_upload_stash':
            ensure  => present,
            command => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php ${runner}/srv/mediawiki/${version}/maintenance/cleanupUploadStash.php",
            user    => 'www-data',
            hour    => 1,
            minute  => 0,
        }

        cron { 'purge expired blocks':
            ensure  => present,
            command => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php ${runner}/srv/mediawiki/${version}/maintenance/purgeExpiredBlocks.php",
            user    => 'www-data',
            minute  => '0',
            hour    => '0',
            month   => '*',
            weekday => [ '1' ],
        }

        if $wiki == 'loginwiki' {
            $swift_password = lookup('mediawiki::swift_password')

            cron { 'generate sitemap index':
                ensure  => present,
                command => "/usr/bin/python3 /srv/mediawiki/${version}/extensions/MirahezeMagic/py/generateSitemapIndex.py -A https://swift-lb.miraheze.org/auth/v1.0 -U mw:media -K ${swift_password} >> /var/log/mediawiki/cron/generate-sitemap-index.log",
                user    => 'www-data',
                minute  => '0',
                hour    => '0',
                month   => '*',
                weekday => [ '5' ],
            }

            cron { 'purge_parsercache':
                ensure  => present,
                command => "/usr/bin/php ${runner}/srv/mediawiki/${version}/maintenance/purgeParserCache.php --wiki loginwiki --tag pc1 --age 864000 --msleep 200",
                user    => 'www-data',
                special => 'daily',
            }

            cron { 'update_special_pages':
                ensure   => present,
                command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php ${runner}/srv/mediawiki/${version}/maintenance/updateSpecialPages.php > /var/log/mediawiki/cron/updateSpecialPages.log 2>&1",
                user     => 'www-data',
                monthday => '*/3',
                hour     => 5,
                minute   => 0,
            }

            # Backups
            file { '/srv/backups':
                ensure => directory,
            }

            cron { 'backups-mediawiki-xml':
                ensure   => absent,
                command  => '/usr/local/bin/wikitide-backup backup mediawiki-xml > /var/log/mediawiki-xml-backup.log 2>&1',
                user     => 'root',
                minute   => '0',
                hour     => '1',
                monthday => ['27'],
                month    => ['3', '6', '9', '12'],
            }

            monitoring::nrpe { 'Backups MediaWiki XML':
                ensure   => absent,
                command  => '/usr/lib/nagios/plugins/check_file_age -w 8640000 -c 11232000 -f /var/log/mediawiki-xml-backup.log',
                docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
                critical => true
            }
        }

        if $wiki == 'loginwikibeta' {
            cron { 'purge_parsercache':
                ensure  => present,
                command => "/usr/bin/php ${runner}/srv/mediawiki/${version}/maintenance/purgeParserCache.php --wiki loginwikibeta --tag pc1 --age 864000 --msleep 200",
                user    => 'www-data',
                special => 'daily',
            }
        }

        cron { 'update_statistics':
            ensure   => present,
            command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php ${runner}/srv/mediawiki/${version}/maintenance/initSiteStats.php --update --active > /dev/null",
            user     => 'www-data',
            minute   => '0',
            hour     => '5',
            monthday => [ '1', '15' ],
        }

        cron { 'update_sites':
            ensure   => present,
            command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php ${runner}/srv/mediawiki/${version}/extensions/MirahezeMagic/maintenance/populateWikibaseSitesTable.php > /dev/null",
            user     => 'www-data',
            minute   => '0',
            hour     => '5',
            monthday => [ '5', '20' ],
        }

        cron { 'clean_gu_cache':
            ensure   => present,
            command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php ${runner}/srv/mediawiki/${version}/extensions/GlobalUsage/maintenance/refreshGlobalimagelinks.php --pages=existing,nonexisting > /dev/null",
            user     => 'www-data',
            minute   => '0',
            hour     => '5',
            monthday => [ '6', '21' ],
        }
    }
}
