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
        notify  => Service['jobrunner'],
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
        command => '/usr/bin/nice -19 /usr/bin/php /srv/mediawiki/w/extensions/CreateWiki/maintenance/manageInactiveWikis.php --wiki loginwiki --write > /var/log/mediawiki/cron/managewikis.log',
        user    => 'www-data',
        minute  => '5',
        hour    => '12',
    }

    cron { 'update rottenlinks on all wikis':
        ensure  => present,
        command => '/usr/local/bin/fileLockScript.sh /tmp/rotten_links_file_lock "/usr/bin/nice -19 /usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/RottenLinks/maintenance/updateExternalLinks.php"',
        user    => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        monthday => [ '14', '28' ],
    }

    cron { 'generate sitemaps for all wikis':
        ensure  => present,
        command => '/usr/bin/nice -19 /usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/generateMirahezeSitemap.php',
        user    => 'www-data',
        minute   => '0',
        hour     => '0',
        month    => '*',
        weekday => [ '6' ],
    }

    file { '/usr/lib/nagios/plugins/check_jobqueue':
        ensure => present,
        source => 'puppet:///modules/mediawiki/jobrunner/check_jobqueue',
        mode   => '0555',
    }

    monitoring::services { 'JobRunner Service':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_jobrunner',
        },
    }

    monitoring::services { 'JobChron Service':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_jobchron',
        },
    }

    monitoring::services { 'JobQueue':
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
