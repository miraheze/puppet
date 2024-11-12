# === Class mediawiki::jobqueue::runner
#
# Defines a jobrunner process for jobrunner selected machine only.
class mediawiki::jobqueue::runner (
    String $version,
) {

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
        systemd::timer::job { 'purge-checkuser':
            description       => 'Purges checkuser',
            command           => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/CheckUser/maintenance/purgeOldData.php",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => '*-*-* 06:05:00',
            },
            logfile_basedir   => '/var/log/mediawiki/cron',
            logfile_name      => 'purge-checkuser.log',
            syslog_identifier => 'purge-checkuser',
            user              => 'www-data',
            require           => File['/var/log/mediawiki/cron'],
        }

        systemd::timer::job { 'purge-abusefilter':
            description       => 'Purges abusefilter',
            command           => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/AbuseFilter/maintenance/PurgeOldLogIPData.php",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => '*-*-* 18:05:00',
            },
            logfile_basedir   => '/var/log/mediawiki/cron',
            logfile_name      => 'purge-abusefilter.log',
            syslog_identifier => 'purge-abusefilter',
            user              => 'www-data',
            require           => File['/var/log/mediawiki/cron'],
        }

        systemd::timer::job { 'managewikis':
            description       => 'Check for inactive wikis',
            command           => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/CreateWiki/maintenance/manageInactiveWikis.php --wiki ${wiki} --write",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => '*-*-* 12:05:00',
            },
            logfile_basedir   => '/var/log/mediawiki/cron',
            logfile_name      => 'managewikis.log',
            syslog_identifier => 'managewikis',
            user              => 'www-data',
            require           => File['/var/log/mediawiki/cron'],
        }

        systemd::timer::job { 'generate-sitemaps':
            description       => 'Create sitemaps for all wikis',
            command           => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/MirahezeMagic/maintenance/generateMirahezeSitemap.php",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => 'Sat *-*-* 00:00:00',
            },
            logfile_basedir   => '/var/log/mediawiki/cron',
            logfile_name      => 'generate-sitemaps.log',
            syslog_identifier => 'generate-sitemaps',
            user              => 'www-data',
            require           => File['/var/log/mediawiki/cron'],
        }

        systemd::timer::job { 'cleanup-upload-stash':
            description       => 'Cleanup upload stash',
            command           => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/cleanupUploadStash.php",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => '*-*-* 01:00:00',
            },
            logfile_basedir   => '/var/log/mediawiki/cron',
            logfile_name      => 'cleanup-upload-stash.log',
            syslog_identifier => 'cleanup-upload-stash',
            user              => 'www-data',
            require           => File['/var/log/mediawiki/cron'],
        }

        systemd::timer::job { 'purge-expired-blocks':
            description       => 'Purge expired blocks',
            command           => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/purgeExpiredBlocks.php",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => 'Mon *-*-* 00:00:00',
            },
            logfile_basedir   => '/var/log/mediawiki/cron',
            logfile_name      => 'purge-expired-blocks.log',
            syslog_identifier => 'purge-expired-blocks',
            user              => 'www-data',
            require           => File['/var/log/mediawiki/cron'],
        }

        if $wiki == 'loginwiki' {
            $swift_password = lookup('mediawiki::swift_password')

            systemd::timer::job { 'generate-sitemap-index':
                description       => 'Create sitemap index',
                command           => "/usr/bin/python3 /srv/mediawiki/${version}/extensions/MirahezeMagic/py/generateSitemapIndex.py -A https://swift-lb.miraheze.org/auth/v1.0 -U mw:media -K ${swift_password}",
                interval          => {
                    'start'    => 'OnCalendar',
                    'interval' => 'Fri *-*-* 00:00:00',
                },
                logfile_basedir   => '/var/log/mediawiki/cron',
                logfile_name      => 'generate-sitemap-index.log',
                syslog_identifier => 'generate-sitemap-index',
                user              => 'www-data',
                require           => File['/var/log/mediawiki/cron'],
            }

            systemd::timer::job { 'purge-parsercache':
                description       => 'Purge parsercache',
                command           => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/purgeParserCache.php --wiki loginwiki --tag pc1 --age 864000 --msleep 200",
                interval          => {
                    'start'    => 'OnCalendar',
                    'interval' => '*-*-* 00:00:00',
                },
                logfile_basedir   => '/var/log/mediawiki/cron',
                logfile_name      => 'purge-parsercache.log',
                syslog_identifier => 'purge-parsercache',
                user              => 'www-data',
                require           => File['/var/log/mediawiki/cron'],
            }

            systemd::timer::job { 'update-special-pages':
                description       => 'Purge parsercache',
                command           => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/updateSpecialPages.php",
                interval          => {
                    'start'    => 'OnCalendar',
                    'interval' => '*-1/3 05:00',
                },
                logfile_basedir   => '/var/log/mediawiki/cron',
                logfile_name      => 'update-special-pages.log',
                syslog_identifier => 'update-special-pages',
                user              => 'www-data',
                require           => File['/var/log/mediawiki/cron'],
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
            systemd::timer::job { 'purge-parsercache':
                description       => 'Purge parsercache',
                command           => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/purgeParserCache.php --wiki loginwikibeta --tag pc1 --age 864000 --msleep 200",
                interval          => {
                    'start'    => 'OnCalendar',
                    'interval' => '*-*-* 00:00:00',
                },
                logfile_basedir   => '/var/log/mediawiki/cron',
                logfile_name      => 'purge-parsercache.log',
                syslog_identifier => 'purge-parsercache',
                user              => 'www-data',
                require           => File['/var/log/mediawiki/cron'],
            }
        }

        systemd::timer::job { 'update-statistics':
            description       => 'Update site statistics',
            command           => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/initSiteStats.php --update --active",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => '*-*-1,15 05:00:00',
            },
            logfile_basedir   => '/var/log/mediawiki/cron',
            logfile_name      => 'update-statistics.log',
            syslog_identifier => 'update-statistics',
            user              => 'www-data',
            require           => File['/var/log/mediawiki/cron'],
        }

        systemd::timer::job { 'update-wikibase-sites-table':
            description       => 'Update site statistics',
            command           => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/MirahezeMagic/maintenance/populateWikibaseSitesTable.php",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => '*-*-5,20 05:00:00',
            },
            logfile_basedir   => '/var/log/mediawiki/cron',
            logfile_name      => 'update-wikibase-sites-table.log',
            syslog_identifier => 'update-wikibase-sites-table',
            user              => 'www-data',
            require           => File['/var/log/mediawiki/cron'],
        }
    }
}
