# === Class mediawiki::jobqueue::chron
#
# JobQueue Chron runner on redis masters only
class mediawiki::jobqueue::chron (
    Hash $versions = lookup('mediawiki::multiversion::versions'),
) {
    include mediawiki::php

    if lookup('mediawiki::use_cpjobqueue', {'default_value' => false}) {
        if !defined(Class['mediawiki::jobqueue::shared']) {
            $versions.each |$version, $params| {
                if $params['default'] {
                    class { 'mediawiki::jobqueue::shared':
                        ensure  => absent,
                        version => $version,
                    }
                }
            }
        }
        systemd::service { 'jobchron':
            ensure  => absent,
            content => systemd_template('jobchron'),
        }
    } else {
        if !defined(Class['mediawiki::jobqueue::shared']) {
            $versions.each |$version, $params| {
                if $params['default'] {
                    class { 'mediawiki::jobqueue::shared':
                        version => $version,
                    }
                }
            }
        }
        systemd::service { 'jobchron':
            ensure    => present,
            content   => systemd_template('jobchron'),
            subscribe => File['/srv/jobrunner/jobrunner.json'],
            restart   => true,
        }

        monitoring::nrpe { 'JobChron Service':
            command => '/usr/lib/nagios/plugins/check_procs -a redisJobChronService -c 1:1',
            docs    => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#JobChron_Service'
        }
    }
}
