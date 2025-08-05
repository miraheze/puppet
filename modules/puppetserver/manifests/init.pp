# == Class: puppetserver
#
# Configures an openvox server using the openvox debian repo.
#
# === Parameters
#
# [*use_puppetdb*] Enables or disable openvoxdb support.
#
# [*puppet_major_version*] Specify the openvox-server version you want to support / install.
#
# [*puppetserver_hostname*] Hostname of the openvox server.
#
# [*puppetserver_java_opts*] Options to pass to the openvox server, eg configuring the heap.
#
class puppetserver(
    String  $puppetdb_hostname,
    Boolean $puppetdb_enable,
    Integer $puppet_major_version,
    String  $puppetserver_hostname,
    String  $puppetserver_java_opts,
) {
    package { 'openvox-server':
        ensure  => present,
        require => Apt::Source['openvox'],
    }

    file { '/usr/bin/puppetserver':
        ensure  => link,
        target  => '/opt/puppetlabs/bin/puppetserver',
        require => Package['openvox-server'],
    }

    file { '/etc/default/puppetserver':
        ensure  => present,
        content => template('puppetserver/puppetserver.erb'),
        require => Package['openvox-server'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/auth.conf':
        ensure  => present,
        source  => 'puppet:///modules/puppetserver/auth.conf',
        require => Package['openvox-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/fileserver.conf':
        ensure  => present,
        source  => 'puppet:///modules/puppetserver/fileserver.conf',
        require => Package['openvox-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/hiera.yaml':
        ensure  => present,
        source  => 'puppet:///modules/puppetserver/hiera.yaml',
        require => Package['openvox-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/puppet.conf':
        ensure  => present,
        content => template('puppetserver/puppet.conf.erb'),
        require => Package['openvox-agent'],
        notify  => Service['puppetserver'],
    }

    git::clone { 'puppet':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/git',
        origin    => 'https://github.com/miraheze/puppet',
        require   => Package['openvox-agent'],
    }

    git::clone { 'ssl':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/ssl-cert',
        origin    => 'https://github.com/miraheze/ssl',
        require   => Package['openvox-agent'],
    }

    git::clone { 'mediawiki-repos':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/mediawiki-repos',
        origin    => 'https://github.com/miraheze/mediawiki-repos',
        owner     => 'puppet',
        group     => 'puppet',
        require   => Package['openvox-agent'],
    }

    git::clone { 'pywikibot-config':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/pywikibot-config',
        origin    => 'https://github.com/miraheze/pywikibot-config',
        owner     => 'puppet',
        group     => 'puppet',
        require   => Package['openvox-agent'],
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
        require => Package['openvox-server'],
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
        require  => Package['openvox-server'],
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
            start    => 'OnCalendar',
            interval => '*-*-* *:09,19,29,39,49,59',
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
            start    => 'OnCalendar',
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
            start    => 'OnCalendar',
            interval => '*-*-* *:05,15,25,35,45,55',
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
    backup::job { 'sslkeys':
        ensure   => present,
        interval => 'Sun *-*-* 06:00:00',
    }

    backup::job { 'private':
        ensure   => present,
        interval => 'Sun *-*-* 03:00:00',
    }
}
