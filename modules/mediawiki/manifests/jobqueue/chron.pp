# === Class mediawiki::jobqueue::chron
#
# JobQueue Chron runner on redis masters only
class mediawiki::jobqueue::chron {
    include ::mediawiki::php

    git::clone { 'JobRunner':
        ensure    => latest,
        directory => '/srv/jobrunner',
        origin    => 'https://github.com/miraheze/jobrunner-service',
    }

    $redis_password = lookup('passwords::redis::master')
    $redis_server_ip = lookup('mediawiki::jobqueue::runner::redis_ip', {'default_value' => '[2a10:6740::6:306]:6379'})
    file { '/srv/jobrunner/jobrunner.json':
        ensure  => present,
        content => template('mediawiki/jobrunner.json.erb'),
        notify  => Service['jobchron'],
        require => Git::Clone['JobRunner'],
    }

    systemd::service { 'jobchron':
        ensure  => present,
        content => systemd_template('jobchron'),
        restart => true,
    }

    monitoring::services { 'JobChron Service':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_jobchron',
        },
    }
}
