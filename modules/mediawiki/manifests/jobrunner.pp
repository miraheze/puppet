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

    cron { 'managewikis':
        ensure  => present,
        command => '/usr/bin/nice -19 /usr/bin/php /srv/mediawiki/w/extensions/CreateWiki/maintenance/manageInactiveWikis.php --wiki loginwiki --warn --close > /var/log/mediawiki/cron/managewikis.log',
        user    => 'www-data',
        minute  => '5',
        hour    => '12',
    }

    cron { 'RotenLinks updateExternalLinks.php on all wikis':
        ensure  => present,
        command => '/usr/bin/nice -19 /usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/RottenLinks/maintenance/updateExternalLinks.php',
        user    => 'www-data',
        minute  => '*',
        hour    => '23',
        weekday => ['0', '4'],
    }

    file { '/usr/lib/nagios/plugins/check_jobqueue':
        ensure => present,
        source => 'puppet:///modules/mediawiki/jobrunner/check_jobqueue',
        mode   => '0555',
    }

    icinga2::custom::services { 'JobRunner Service':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_jobrunner',
        },
    }

    icinga2::custom::services { 'JobChron Service':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_jobchron',
        },
    }

    icinga2::custom::services { 'JobQueue':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_jobqueue',
        },
    }

    sudo::user { 'nrpe_sudo_check_jobqueue':
        user       => 'nagios',
        privileges => [ 'ALL = (www-data) NOPASSWD: /usr/lib/nagios/plugins/check_jobqueue' ],
    }
}
