# === Class mediawiki::jobqueue::chron
#
# JobQueue Chron runner on redis masters only
class mediawiki::jobqueue::chron {
    include mediawiki::php
    include mediawiki::jobqueue::shared

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
