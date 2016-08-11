# class: mediawiki::jobrunner
#
# Crons which should be ran on a jobrunner selected machine only.
class mediawiki::jobrunner {
    git::clone { 'JobRunner':
        directory   => '/srv/jobrunner',
        origin      => 'https://github.com/wikimedia/mediawiki-services-jobrunner',
    }

    $redis_password = hiera('passwords::redis::master')

    file { '/srv/jobrunner/jobrunner.json':
        ensure  => present,
        content => template('mediawiki/jobrunner.json.erb'),
        require => Git::Clone['JobRunner'],
    }

    file { '/etc/init.d/jobrunner':
        ensure  => present,
        mode    => 0755,
        source  => 'puppet:///modules/mediawiki/jobrunner/jobrunner.initd',
    }

    exec { 'JobRunner reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/jobrunner.service':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/jobrunner/jobrunner.systemd',
        notify  => Exec['JobRunner reload systemd'],
    }
	
    cron { 'jobqueue':
        ensure  => absent,
        command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/maintenance/runJobs.php > /var/log/mediawiki/cron/jobqueue.log',
        user    => 'www-data',
        minute  => '*/15',
    }

    cron { 'purge_checkuser':
        ensure  => present,
        command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/CheckUser/maintenance/purgeOldData.php > /var/log/mediawiki/cron/purge_checkuser.log',
        user    => 'www-data',
        minute  => '0',
        hour    => '*/12',
    }

    cron { 'purge_abusefilter':
        ensure => present,
        command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/AbuseFilter/maintenance/purgeOldLogIPData.php > /var/log/mediawiki/cron/purge_abusefilter.log',
        user    => 'www-data',
        minute  => '0',
        hour    => '*/12',
    }
}
