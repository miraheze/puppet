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
            command           => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php CreateWiki:ManageInactiveWikis --wiki ${wiki} --write",
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
            command           => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php MirahezeMagic:GenerateMirahezeSitemap",
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

        systemd::timer::job { 'refreshlinks':
            description       => 'refreshlinks',
            command           => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/refreshLinks.php --dfn-only",
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => '*-1 00:00',
            },
            logfile_basedir   => '/var/log/mediawiki/cron',
            logfile_name      => 'refreshlinks.log',
            syslog_identifier => 'refreshlinks',
            user              => 'www-data',
            require           => File['/var/log/mediawiki/cron'],
        }

        if $wiki == 'loginwiki' {
            $swift_password = lookup('mediawiki::swift_password')

            systemd::timer::job { 'generate-sitemap-index':
                description       => 'Create sitemap index',
                command           => "/usr/bin/python3 /srv/mediawiki/${version}/extensions/MirahezeMagic/py/generate_sitemap_index.py -A https://swift-lb.wikitide.net/auth/v1.0 -U mw:media -K ${swift_password}",
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
                command           => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/purgeParserCache.php --wiki loginwiki --tag pc1 --age 1296000 --msleep 200",
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

            systemd::timer::job { 'purge-loginnotify':
                description       => 'Purge loginnotify',
                command           => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/LoginNotify/maintenance/purgeSeen.php --wiki loginwiki",
                interval          => {
                    'start'    => 'OnCalendar',
                    'interval' => '*-*-* 23:00:00',
                },
                logfile_basedir   => '/var/log/mediawiki/cron',
                logfile_name      => 'purge-loginnotify.log',
                syslog_identifier => 'purge-loginnotify',
                user              => 'www-data',
                require           => File['/var/log/mediawiki/cron'],
            }

            systemd::timer::job { 'update-special-pages':
                description       => 'Update Special Pages',
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
        }

        if $wiki == 'loginwikibeta' {
            systemd::timer::job { 'purge-parsercache':
                description       => 'Purge parsercache',
                command           => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/purgeParserCache.php --wiki loginwikibeta --tag pc1 --age 1296000 --msleep 200",
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

            systemd::timer::job { 'purge-loginnotify':
                description       => 'Purge loginnotify',
                command           => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/LoginNotify/maintenance/purgeSeen.php --wiki loginwikibeta",
                interval          => {
                    'start'    => 'OnCalendar',
                    'interval' => '*-*-* 23:00:00',
                },
                logfile_basedir   => '/var/log/mediawiki/cron',
                logfile_name      => 'purge-loginnotify.log',
                syslog_identifier => 'purge-loginnotify',
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
            description       => 'Update Wikibase Sites Table',
            command           => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php MirahezeMagic:PopulateWikibaseSitesTable --wiki=${wiki} --all-wikis",
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

        stdlib::ensure_packages(['python3-internetarchive'])

        file { '/usr/local/bin/iaupload':
            ensure => present,
            mode   => '0755',
            source => 'puppet:///modules/mediawiki/bin/iaupload.py',
        }

        file { '/usr/local/bin/backupwikis':
            ensure => 'present',
            mode   => '0755',
            source => 'puppet:///modules/mediawiki/bin/backupwikis',
        }

        file { '/opt/backups':
            ensure => directory,
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0755',
        }

        systemd::timer::job { 'backup-all-wikis-ia':
            description       => 'Backups all wikis for IA',
            command           => '/usr/local/bin/backupwikis /srv/mediawiki/cache/public.php',
            interval          => {
                'start'    => 'OnCalendar',
                'interval' => 'monthly',
            },
            logfile_basedir   => '/var/log/mediawiki/cron',
            logfile_name      => 'iabackup-backup.log',
            syslog_identifier => 'iabackup-backup',
            user              => 'www-data',
            require           => File['/var/log/mediawiki/cron'],
        }
    }
}
