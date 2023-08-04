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
# [*puppetserver_hostname*] Hostname of the puppetserver, eg puppet1.miraheze.org.
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
        ensure    => present,
        directory => '/etc/puppetlabs/puppet/git',
        origin    => 'https://github.com/miraheze/puppet.git',
        require   => Package['puppet-agent'],
    }

    git::clone { 'ssl':
        ensure    => present,
        directory => '/etc/puppetlabs/puppet/ssl-cert',
        origin    => 'https://github.com/miraheze/ssl.git',
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

    cron { 'puppet-git':
        command => '/usr/bin/git -C /etc/puppetlabs/puppet/git pull > /dev/null 2>&1',
        user    => 'root',
        hour    => '*',
        minute  => [ '9', '19', '29', '39', '49', '59' ],
    }

    cron { 'ssl-git':
        command => '/usr/bin/git -C /etc/puppetlabs/puppet/ssl-cert pull > /dev/null 2>&1',
        user    => 'root',
        hour    => '*',
        minute  => [ '9', '19', '29', '39', '49', '59' ],
    }

    cron { 'puppet-old-reports-remove':
        ensure  => present,
        command => 'find /opt/puppetlabs/server/data/puppetserver/reports -type f -mmin +100 -delete >/dev/null 2>&1',
        user    => 'root',
        hour    => '*/1',
        minute  => '*',
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

    cron { 'geoipupdate':
        ensure   => present,
        command  => '/root/geoipupdate',
        user     => 'root',
        monthday => 1,
        hour     => 12,
        minute   => 0,
    }

    file { '/root/updatesfs':
        ensure  => present,
        content => template('puppetserver/updatesfs'),
        mode    => '0555',
    }

    cron { 'updatesfs':
        ensure   => present,
        command  => '/root/updatesfs',
        user     => 'root',
        hour     => 23,
        minute   => 0,
    }
    
    monitoring::services { 'puppetserver':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '8140',
        },
    }

    # Backups
    cron { 'backups-sslkeys':
        ensure  => present,
        command => '/usr/local/bin/miraheze-backup backup sslkeys > /var/log/sslkeys-backup.log 2>&1',
        user    => 'root',
        minute  => '0',
        hour    => '6',
        weekday => '0',
    }
    
    monitoring::nrpe { 'Backups SSLKeys':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 864000 -c 1209600 -f /var/log/sslkeys-backup.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }

    cron { 'backups-private':
        ensure  => present,
        command => '/usr/local/bin/miraheze-backup backup private > /var/log/private-backup.log 2>&1',
        user    => 'root',
        minute  => '0',
        hour    => '3',
        weekday => '0',
    }

    monitoring::nrpe { 'Backups Private':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 864000 -c 1209600 -f /var/log/private-backup.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }
}
