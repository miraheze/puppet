class puppetmaster(
    $dbserver   = undef,
    $dbname     = undef,
    $dbuser     = undef,
  ) {
    $packages = [
        'libmysqld-dev',
        'puppetmaster',
        'puppet-common',
    ]

    package { $packages:
        ensure => present,
    }

    $dbpassword = hiera('puppetmaster::dbpassword')

    file { '/etc/puppet/puppet.conf':
        ensure  => present,
        content => template('puppetmaster/puppet.conf'),
        require => Package['puppetmaster'],
        notify  => Service['puppetmaster'],
    }

    file { '/etc/puppet/auth.conf':
        ensure  => present,
        source  => 'puppet:///modules/puppetmaster/auth.conf',
        require => Package['puppetmaster'],
        notify  => Service['puppetmaster'],

    }

    file { '/etc/puppet/fileserver.conf':
        ensure  => present,
        source  => 'puppet:///modules/puppetmaster/fileserver.conf',
        require => Package['puppetmaster'],
        notify  => Service['puppetmaster'],

    }

    file { '/etc/puppet/git':
        ensure => directory,
    }

    file { '/etc/puppet/private':
        ensure => directory,
    }

    service { 'puppetmaster':
        ensure => running,
    }

    ufw::allow { 'puppetmaster':
        proto => 'tcp',
        port => '8140',
    }

    file { '/etc/puppet/manifests':
        ensure => link,
        target => '/etc/puppet/git/manifests',
    }

    file { '/etc/puppet/modules':
        ensure => link,
        target => '/etc/puppet/git/modules',
    }
}
