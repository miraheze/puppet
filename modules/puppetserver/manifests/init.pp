# == Class: puppetserver
#
# Configures a puppetserver using puppetlabs debian repo.
#
# === Parameters
#
# [*use_puppetdb*] Enables or disable puppetdb support.
#
# [*puppet_major_version*] Specify the puppetserver version you want to support / install.
#
# [*puppetserver_hostname*] Hostname of the puppetserver.
#
# [*puppetserver_java_opts*] Options to pass to the puppetserver, eg configuring the heap.
#
class puppetserver(
    String  $puppetdb_hostname,
    Boolean $puppetdb_enable,
    Integer $puppet_major_version,
    String  $puppetserver_hostname,
    String  $puppetserver_java_opts,
) {
    package { 'puppetserver':
        ensure  => present,
        require => Apt::Source['puppetlabs'],
    }

    file { '/usr/bin/puppetserver':
        ensure  => link,
        target  => '/opt/puppetlabs/bin/puppetserver',
        require => Package['puppetserver'],
    }

    file { '/etc/default/puppetserver':
        ensure  => present,
        content => template('puppetserver/puppetserver.erb'),
        require => Package['puppetserver'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/auth.conf':
        ensure  => present,
        source  => 'puppet:///modules/puppetserver/auth.conf',
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/fileserver.conf':
        ensure  => present,
        source  => 'puppet:///modules/puppetserver/fileserver.conf',
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/hiera.yaml':
        ensure  => present,
        source  => 'puppet:///modules/puppetserver/hiera.yaml',
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/puppet.conf':
        ensure  => present,
        content => template('puppetserver/puppet.conf.erb'),
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    git::clone { 'puppet':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/git',
        origin    => 'https://github.com/miraheze/puppet',
        require   => Package['puppet-agent'],
    }

    git::clone { 'ssl':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/ssl-cert',
        origin    => 'https://github.com/miraheze/ssl',
        require   => Package['puppet-agent'],
    }

    git::clone { 'mediawiki-repos':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/mediawiki-repos',
        origin    => 'https://github.com/miraheze/mediawiki-repos',
        owner     => 'puppet',
        group     => 'puppet',
        require   => Package['puppet-agent'],
    }

    git::clone { 'pywikibot-config':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/pywikibot-config',
        origin    => 'https://github.com/miraheze/pywikibot-config',
        owner     => 'puppet',
        group     => 'puppet',
        require   => Package['puppet-agent'],
    }

    file { '/etc/puppetlabs/puppet/private':
        ensure => directory,
    }

    file { '/etc/puppetlabs/puppet/hieradata':
        ensure  => link,
        target  => '/etc/puppetlabs/puppet/git/hieradata',
        require => Git::Clone['puppet'],
    }

    file { '/etc/puppetlabs/puppet/manifests':
        ensure  => link,
        target  => '/etc/puppetlabs/puppet/git/manifests',
        require => Git::Clone['puppet'],
    }

    file { '/etc/puppetlabs/puppet/modules':
        ensure  => link,
        target  => '/etc/puppetlabs/puppet/git/modules',
        require => Git::Clone['puppet'],
    }

    file { '/etc/puppetlabs/puppet/environments':
        ensure  => directory,
        mode    => '0775',
        require => Package['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/environments/production':
        ensure  => directory,
        mode    => '0775',
        require => File['/etc/puppetlabs/puppet/environments'],
    }

    file { '/etc/puppetlabs/puppet/environments/production/manifests':
        ensure  => link,
        target  => '/etc/puppetlabs/puppet/manifests',
        require => [
            File['/etc/puppetlabs/puppet/environments/production'],
            File['/etc/puppetlabs/puppet/manifests']
        ],
    }

    file { '/etc/puppetlabs/puppet/environments/production/modules':
        ensure  => link,
        target  => '/etc/puppetlabs/puppet/git/modules',
        require => [
            File['/etc/puppetlabs/puppet/environments/production'],
            File['/etc/puppetlabs/puppet/modules']
        ],
    }

    file { '/etc/puppetlabs/puppet/environments/production/ssl-cert':
        ensure  => link,
        target  => '/etc/puppetlabs/puppet/ssl-cert',
        require => [
            File['/etc/puppetlabs/puppet/environments/production'],
            Git::Clone['ssl']
        ],
    }

    if $puppetdb_enable {
        class { 'puppetserver::puppetdb::client':
            puppetdb_hostname => $puppetdb_hostname,
        }
    }

    file { '/etc/puppetlabs/puppetserver/logback.xml':
        ensure => present,
        source => 'puppet:///modules/puppetserver/puppetserver_logback.xml',
        notify => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppetserver/request-logging.xml':
        ensure => present,
        source => 'puppet:///modules/puppetserver/puppetserver-request-logging.xml',
        notify => Service['puppetserver'],
    }

    rsyslog::input::file { 'puppetserver':
        path              => '/var/log/puppetlabs/puppetserver/puppetserver.log.json',
        syslog_tag_prefix => '',
        use_udp           => true,
    }

    rsyslog::input::file { 'puppetserver-access':
        path              => '/var/log/puppetlabs/puppetserver/puppetserver-access.log.json',
        syslog_tag_prefix => '',
        use_udp           => true,
    }

    service { 'puppetserver':
        ensure   => running,
        enable   => true,
        provider => 'systemd',
        require  => Package['puppetserver'],
    }

    ferm::service { 'puppetserver':
        proto => 'tcp',
        port  => '8140',
    }

    systemd::timer::job { 'git_pull_puppet':
        ensure          => present,
        description     => 'Pull changes on the puppet repo',
        command         => '/bin/bash -c "cd /etc/puppetlabs/puppet/git && /usr/bin/git pull>/dev/null 2>&1"',
        interval        => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-* *:09,19,29,39,49,59',
        },
        logging_enabled => false,
        user            => 'root',
    }

    systemd::timer::job { 'git_pull_ssl':
        ensure          => present,
        description     => 'Pull changes on the ssl repo',
        command         => '/bin/bash -c "cd /etc/puppetlabs/puppet/ssl-cert && /usr/bin/git pull>/dev/null 2>&1"',
        interval        => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-* *:09,19,29,39,49,59',
        },
        logging_enabled => false,
        user            => 'root',
    }

    systemd::timer::job { 'remove_old_puppet_reports':
        ensure      => present,
        user        => 'root',
        description => 'Removes puppet reports older than 100 minutes.',
        command     => '/usr/bin/find /opt/puppetlabs/server/data/puppetserver/reports -type f -mmin +100 -delete',
        interval    => { 'start' => 'OnUnitInactiveSec', 'interval' => '1h' },
        path_exists => '/opt/puppetlabs/server/data/puppetserver/reports',
    }

    $geoip_key = lookup('passwords::geoipupdatekey')

    file { '/usr/share/GeoIP':
        ensure => directory,
    }

    file { '/root/geoipupdate':
        ensure  => present,
        content => template('puppetserver/geoipupdate'),
        mode    => '0555',
    }

    systemd::timer::job { 'geoipupdate':
        ensure                  => present,
        description             => 'Run geoipupdate monthly',
        command                 => '/root/geoipupdate',
        interval                => {
            start    => 'OnCalendar',
            interval => '*-01 12:00:00',
        },
        user                    => 'root',
        send_mail               => true,
        send_mail_only_on_error => false,
        send_mail_to            => 'root@wikitide.net',
    }

    file { '/root/updatesfs':
        ensure  => present,
        content => template('puppetserver/updatesfs'),
        mode    => '0555',
    }

    systemd::timer::job { 'updatesfs':
        ensure                  => present,
        description             => 'Run updatesfs nightly',
        command                 => '/root/updatesfs',
        interval                => {
            'start'  => 'OnCalendar',
            interval => '*-*-* 23:00:00',
        },
        user                    => 'root',
        send_mail               => true,
        send_mail_only_on_error => false,
        send_mail_to            => 'root@wikitide.net',
    }

    $cloudflare_api_token = lookup('passwords::cloudflare::listdomains_roapikey')
    $cloudflare_zone_id   = lookup('cloudflare::zone_id')

    file { '/usr/local/bin/listdomains':
        ensure  => present,
        content => template('puppetserver/listdomains.py'),
        mode    => '0555',
    }

    systemd::timer::job { 'listdomains_github_push':
        ensure                  => present,
        description             => 'Refresh custom domains list from Cloudflare and WikiDiscover hourly',
        command                 => '/usr/local/bin/listdomains',
        interval                => {
            start      => 'OnCalendar',
            'interval' => '*-*-* *:05,15,25,35,45,55'
        },
        user                    => 'root',
        send_mail               => true,
        send_mail_only_on_error => false,
        send_mail_to            => 'root@wikitide.net',
    }

    monitoring::services { 'puppetserver':
        check_command => 'tcp',
        vars          => {
            tcp_port => '8140',
        },
    }

    # Backups
    systemd::timer::job { 'backups-sslkeys':
        ensure            => present,
        description       => 'Runs backup of sslkeys',
        command           => '/usr/local/bin/wikitide-backup backup sslkeys',
        interval          => {
            start    => 'OnCalendar',
            interval => 'Sun *-*-* 06:00:00',
        },
        logfile_name      => 'sslkeys-backup.log',
        syslog_identifier => 'sslkeys-backup',
        user              => 'root',
    }

    monitoring::nrpe { 'Backups SSLKeys':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 864000 -c 1209600 -f /var/log/sslkeys-backup/sslkeys-backup.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }

    systemd::timer::job { 'backups-private':
        ensure            => present,
        description       => 'Runs backup of private data',
        command           => '/usr/local/bin/wikitide-backup backup private',
        interval          => {
            start    => 'OnCalendar',
            interval => 'Sun *-*-* 03:00:00',
        },
        logfile_name      => 'private-backup.log',
        syslog_identifier => 'private-backup',
        user              => 'root',
    }

    monitoring::nrpe { 'Backups Private':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 864000 -c 1209600 -f /var/log/private-backup/private-backup.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }
}
