# class: puppetmaster::v6
class puppetmaster::v6(
    String $puppetmaster_hostname,
    Integer $puppetmaster_version,
    Boolean $use_puppetdb,
    String $puppetserver_heap,
) {
    package { 'puppetserver':
        ensure  => present,
        require => Apt::Source['puppetlabs'],
    }

    file { '/etc/default/puppetserver':
        ensure  => present,
        content => template('puppetmaster/puppetserver.erb'),
        require => Package['puppetserver'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppet':
        ensure => directory,
    }

    file { '/etc/puppetlabs/puppet/hiera.yaml':
        ensure  => present,
        source  => "puppet:///modules/puppetmaster/hiera.${puppetmaster_version}.yaml",
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/puppet.conf':
        ensure  => present,
        content => template("puppetmaster/puppet_${puppetmaster_version}.conf.erb"),
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/auth.conf':
        ensure  => present,
        source  => "puppet:///modules/puppetmaster/auth_${puppetmaster_version}.conf",
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    file { '/etc/puppetlabs/puppet/fileserver.conf':
        ensure  => present,
        source  => "puppet:///modules/puppetmaster/fileserver.${puppetmaster_version}.conf",
        require => Package['puppet-agent'],
        notify  => Service['puppetserver'],
    }

    git::clone { 'puppet':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/git',
        origin    => 'https://github.com/miraheze/puppet.git',
        require   => Package['puppet-agent'],
    }

    # work around for new puppet agent
    git::clone { 'services':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/services',
        origin    => 'https://github.com/miraheze/services.git',
        require   => Package['puppet-agent'],
    }

    git::clone { 'ssl':
        ensure    => latest,
        directory => '/etc/puppetlabs/puppet/ssl_cert',
        origin    => 'https://github.com/miraheze/ssl.git',
        require   => Package['puppet-agent'],
    }

    file { '/etc/puppet/ssl':
        ensure  => link,
        target  => '/etc/puppetlabs/puppet/ssl_cert',
        require => [
            Git::Clone['ssl'],
            File['/etc/puppet']
        ],
    }

    file { '/etc/puppetlabs/puppet/private':
        ensure => directory,
    }

    file { '/etc/puppetlabs/puppet/hieradata':
        ensure  => link,
        target  => '/etc/puppetlabs/puppet/git/hieradata',
        require => Git::Clone['puppet'],
    }

    file { '/etc/puppet/hieradata':
        ensure  => link,
        target  => '/etc/puppetlabs/puppet/hieradata',
        require => [
            File['/etc/puppetlabs/puppet/hieradata'],
            File['/etc/puppet']
        ],
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
        target  => '/etc/puppet/modules',
        require => [File['/etc/puppetlabs/puppet/environments/production'], File['/etc/puppet/modules']],
    }

    file { '/etc/puppetlabs/puppet/environments/production/ssl_cert':
        ensure  => link,
        target  => '/etc/puppetlabs/puppet/ssl_cert',
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

    if $use_puppetdb {
        class { 'puppetmaster::puppetdb::client': }
    }

    service { 'puppetserver':
        ensure  => running,
        enable  => true,
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
        command => '/usr/bin/git -C /etc/puppetlabs/puppet/ssl_cert pull',
        user    => 'root',
        hour    => '*',
        minute  => [ '9', '19', '29', '39', '49', '59' ],
    }

    cron { 'puppet-old-reports-remove':
        ensure  => present,
        command => 'find /opt/puppetlabs/server/data/puppetserver/reports -type f -mmin +960 -delete >/dev/null 2>&1',
        user    => 'root',
        hour    => [ '0', '8', '16' ],
        minute  => [ '27' ],
    }
}
