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

    if lookup('mediawiki::jobqueue::runner::periodic_jobs', {'default_value' => false}) {
        mediawiki::periodic_job { 'purge-checkuser':
            command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/CheckUser/maintenance/purgeOldData.php",
            interval => '*-*-* 06:05:00',
        }

        mediawiki::periodic_job { 'purge-abusefilter':
            command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/AbuseFilter/maintenance/PurgeOldLogIPData.php",
            interval => '*-*-* 18:05:00',
        }

        mediawiki::periodic_job { 'manage-inactive-wikis':
            command  => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php CreateWiki:ManageInactiveWikis --wiki ${wiki} --write",
            interval => '*-*-* 12:05:00',
        }

        mediawiki::periodic_job { 'generate-sitemaps':
            command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php MirahezeMagic:GenerateMirahezeSitemap",
            interval => 'Sat *-*-* 00:00:00',
        }

        mediawiki::periodic_job { 'cleanup-upload-stash':
            command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/cleanupUploadStash.php",
            interval => '*-*-* 01:00:00',
        }

        mediawiki::periodic_job { 'purge-expired-blocks':
            command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/purgeExpiredBlocks.php",
            interval => 'Mon *-*-* 00:00:00',
        }

        mediawiki::periodic_job { 'refreshlinks':
            command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/refreshLinks.php --dfn-only",
            interval => '*-1 00:00',
        }

        if $wiki == 'loginwiki' {
            include mediawiki::techdocs
            $swift_password = lookup('mediawiki::swift_password')

            mediawiki::periodic_job { 'generate-sitemap-index':
                command  => "/usr/bin/python3 /srv/mediawiki/${version}/extensions/MirahezeMagic/py/generate_sitemap_index.py -A https://swift-lb.wikitide.net/auth/v1.0 -U mw:media -K ${swift_password}",
                interval => 'Fri *-*-* 00:00:00',
            }

            mediawiki::periodic_job { 'purge-parsercache':
                command  => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/purgeParserCache.php --wiki loginwiki --tag pc1 --age 1296000 --msleep 200",
                interval => '*-*-* 00:00:00',
            }

            mediawiki::periodic_job { 'purge-loginnotify':
                command  => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/LoginNotify/maintenance/purgeSeen.php --wiki loginwiki",
                interval => '*-*-* 23:00:00',
            }

            mediawiki::periodic_job { 'update-special-pages':
                command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/updateSpecialPages.php",
                interval => '*-1/3 05:00',
            }

            stdlib::ensure_packages('python3-internetarchive')

            file { '/usr/local/bin/iaupload':
                ensure => present,
                mode   => '0755',
                source => 'puppet:///modules/mediawiki/bin/iaupload.py',
            }

            file { '/usr/local/bin/backupwikis':
                ensure => present,
                mode   => '0755',
                source => 'puppet:///modules/mediawiki/bin/backupwikis',
            }

            file { '/opt/backups':
                ensure => directory,
                owner  => 'www-data',
                group  => 'www-data',
                mode   => '0755',
            }

            mediawiki::periodic_job { 'backup-all-wikis-ia':
                command  => '/usr/local/bin/backupwikis /srv/mediawiki/cache/public.php',
                interval => 'monthly',
            }
        }

        if $wiki == 'loginwikibeta' {
            mediawiki::periodic_job { 'purge-parsercache':
                command  => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/purgeParserCache.php --wiki loginwikibeta --tag pc1 --age 1296000 --msleep 200",
                interval => '*-*-* 00:00:00',
            }

            mediawiki::periodic_job { 'purge-loginnotify':
                command  => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/extensions/LoginNotify/maintenance/purgeSeen.php --wiki loginwikibeta",
                interval => '*-*-* 23:00:00',
            }

            file { '/usr/local/bin/iaupload':
                ensure => absent,
                mode   => '0755',
                source => 'puppet:///modules/mediawiki/bin/iaupload.py',
            }

            file { '/usr/local/bin/backupwikis':
                ensure => absent,
                mode   => '0755',
                source => 'puppet:///modules/mediawiki/bin/backupwikis',
            }

            mediawiki::periodic_job { 'backup-all-wikis-ia':
                ensure   => absent,
                command  => '/usr/local/bin/backupwikis /srv/mediawiki/cache/public.php',
                interval => 'monthly',
            }
        }

        mediawiki::periodic_job { 'update-statistics':
            command  => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php /srv/mediawiki/${version}/maintenance/run.php /srv/mediawiki/${version}/maintenance/initSiteStats.php --update --active",
            interval => '*-*-1,15 05:00:00',
        }

        mediawiki::periodic_job { 'update-wikibase-sites-table':
            command  => "/usr/bin/php /srv/mediawiki/${version}/maintenance/run.php MirahezeMagic:PopulateWikibaseSitesTable --wiki=${wiki} --all-wikis",
            interval => '*-*-5,20 05:00:00',
        }
    }
}
