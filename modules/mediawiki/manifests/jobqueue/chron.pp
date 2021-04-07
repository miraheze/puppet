# class: mediawiki::jobqueue::chron
#
# JobQueue Chron runner on redis masters only
class mediawiki::jobqueue::chron {
    require mediawiki::jobqueue::runner

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
