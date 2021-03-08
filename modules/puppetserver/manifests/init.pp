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
        source  => "puppet:///modules/puppetserver/auth.${puppet_major_version}.conf",
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/fileserver.conf':
        ensure  => present,
        source  => "puppet:///modules/puppetserver/fileserver.${puppet_major_version}.conf",
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/hiera.yaml':
        ensure  => present,
        source  => "puppet:///modules/puppetserver/hiera.${puppet_major_version}.yaml",
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/puppet.conf':
        ensure  => present,
        content => template("puppetserver/puppet.${puppet_major_version}.conf.erb"),
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    git::clone { 'puppet':
        ensure    => present,
        directory => '/etc/puppetlabs/puppet/git',
        origin    => 'https://github.com/miraheze/puppet.git',
        require   => Package['puppet-agent'],
    }

    git::clone { 'services':
        ensure    => present,
        directory => '/etc/puppetlabs/puppet/services',
        origin    => 'https://github.com/miraheze/services.git',
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

    file { '/home/puppet-users':
        ensure  => directory,
        owner   => 'root',
        group   => 'puppet-users',
        mode    => '0770',
    }
 
    if $puppetdb_enable {
        class { 'puppetserver::puppetdb::client':
            puppetdb_hostname => $puppetdb_hostname,
        }

        file { '/usr/bin/puppetdb':
            ensure  => link,
            target  => '/opt/puppetlabs/bin/puppetdb',
            require => Package['puppetserver'],
        }
    }

    puppetserver::logging { 'puppetserver':
        file_path           => '/etc/puppetlabs/puppetserver/logback.xml',
        file_source         => 'puppet:///modules/puppetserver/puppetserver_logback.xml',
        file_source_options => [
            '/var/log/puppetlabs/puppetserver/puppetserver.log.json',
            { 'flags' => 'no-parse' }
        ],
        program_name        => 'puppetserver',
        notify              => Service['puppetserver'],
    }

    puppetserver::logging { 'puppetserver_access':
        file_path           => '/etc/puppetlabs/puppetserver/request-logging.xml',
        file_source         => 'puppet:///modules/puppetserver/puppetserver-request-logging.xml',
        file_source_options => [
            '/var/log/puppetlabs/puppetserver/puppetserver-access.log.json',
            { 'flags' => 'no-parse' }
        ],
        program_name        => 'puppetserver_access',
        notify              => Service['puppetserver'],
    }

    systemd::service { 'puppetserver':
        ensure  => present,
        content => systemd_template('puppetserver'),
        restart => true,
        require => Package['puppetserver'],
    }

    ufw::allow { 'puppetserver':
        proto => 'tcp',
        port  => '8140',
    }

    cron { 'puppet-git':
        command => '/usr/bin/git -C /etc/puppetlabs/puppet/git pull',
        user    => 'root',
        hour    => '*',
        minute  => [ '9', '19', '29', '39', '49', '59' ],
    }

    cron { 'services-git':
        command => '/usr/bin/git -C /etc/puppetlabs/puppet/services pull',
        user    => 'root',
        hour    => '*',
        minute  => [ '9', '19', '29', '39', '49', '59' ],
    }

    cron { 'ssl-git':
        command => '/usr/bin/git -C /etc/puppetlabs/puppet/ssl-cert pull',
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

    monitoring::services { 'puppetserver':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '8140',
        },
    }
}
