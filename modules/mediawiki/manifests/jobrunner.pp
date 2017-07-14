# class: mediawiki::jobrunner
#
# Crons which should be ran on a jobrunner selected machine only.
class mediawiki::jobrunner {
    git::clone { 'JobRunner':
        directory => '/srv/jobrunner',
        origin    => 'https://github.com/wikimedia/mediawiki-services-jobrunner',
    }

    $redis_password = hiera('passwords::redis::master')

    file { '/srv/jobrunner/jobrunner.json':
        ensure  => present,
        content => template('mediawiki/jobrunner.json.erb'),
        require => Git::Clone['JobRunner'],
    }

    file { '/etc/init.d/jobrunner':
        ensure => present,
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/jobrunner/jobrunner.initd',
    }

    exec { 'JobRunner reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/jobrunner.service':
        ensure => present,
        source => 'puppet:///modules/mediawiki/jobrunner/jobrunner.systemd',
        notify => Exec['JobRunner reload systemd'],
    }

    service { 'jobrunner':
        ensure => running,
    }

    file { '/etc/init.d/jobchron':
        ensure => present,
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/jobrunner/jobchron.initd',
    }

    file { '/etc/systemd/system/jobchron.service':
        ensure => present,
        source => 'puppet:///modules/mediawiki/jobrunner/jobchron.systemd',
        notify => Exec['JobRunner reload systemd'],
    }

    service { 'jobchron':
        ensure => running,
    }

    file { '/etc/rsyslog.d/20-jobrunner.conf':
        ensure => present,
        source => 'puppet:///modules/mediawiki/jobrunner/jobrunner.rsyslog.conf',
        notify => [ Service['rsyslog'], Service['jobchron'], Service['jobrunner'] ],
    }

    cron { 'purge_checkuser':
        ensure  => present,
        command => '/usr/bin/nice -19 /usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/CheckUser/maintenance/purgeOldData.php > /var/log/mediawiki/cron/purge_checkuser.log',
        user    => 'www-data',
        minute  => '5',
        hour    => '6',
    }

    cron { 'purge_abusefilter':
        ensure  => present,
        command => '/usr/bin/nice -19 /usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/AbuseFilter/maintenance/purgeOldLogIPData.php > /var/log/mediawiki/cron/purge_abusefilter.log',
        user    => 'www-data',
        minute  => '5',
        hour    => '18',
    }

    file { '/usr/lib/nagios/plugins/check_jobqueue':
        ensure => present,
        source => 'puppet:///modules/mediawiki/jobrunner/check_jobqueue',
        mode   => '0555',
    }

    icinga::service { 'jobrunner':
        description   => 'JobRunner Service',
        check_command => 'check_nrpe_1arg!check_jobrunner',
    }

    icinga::service { 'jobchron':
        description   => 'JobChron Service',
        check_command => 'check_nrpe_1arg!check_jobchron',
    }

    icinga::service { 'jobqueue':
        description   => 'JobQueue',
        check_command => 'check_nrpe_1arg!check_jobqueue',
    }
}
