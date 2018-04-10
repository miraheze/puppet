
class mathoid {
    include ::apt

    apt::source { 'nodejs_6':
        comment  => 'NodeJS 6',
        location => 'http://deb.nodesource.com/node_6.x/',
        release  => "${::lsbdistcodename}",
        repos    => 'main',
        key      => '9FD3B784BC1C6FC31A8A0A1C1655A0AB68576280',
    }

    package { 'nodejs':
        ensure  => present,
        require => Apt::Source['nodejs_6']
    }

    file { '/etc/mathoid':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/etc/mathoid/config.yaml':
        ensure  => present,
        source  => 'puppet:///modules/mathoid/config.mathoid.yaml',
        require => File['/etc/mathoid'],
        notify  => Service['mathoid'],
    }

    file { '/etc/restbase':
        ensure => directory,
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    file { '/etc/restbase/config.yaml':
        ensure  => present,
        owner   => 'www-data',
        group   => 'www-data',
        source  => 'puppet:///modules/mathoid/config.restbase.yaml',
        require => File['/etc/restbase'],
        notify  => Service['restbase'],
    }

    git::clone { 'mathoid':
        ensure             => 'latest',
        directory          => '/srv/mathoid',
        origin             => 'https://github.com/wikimedia/mathoid',
        branch             => 'v0.7.1',
        owner              => 'www-data',
        group              => 'www-data',
        mode               => '0755',
        timeout            => '550',
        recurse_submodules => true,
    }

    git::clone { 'restbase':
        ensure             => 'latest',
        directory          => '/srv/restbase',
        origin             => 'https://github.com/wikimedia/restbase',
        branch             => 'v0.18.1',
        owner              => 'www-data',
        group              => 'www-data',
        mode               => '0755',
        timeout            => '550',
        recurse_submodules => true,
    }

    exec { 'mathoid reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/mathoid.service':
        ensure => present,
        source => 'puppet:///modules/mathoid/mathoid.systemd',
        notify => Exec['mathoid reload systemd'],
    }

    service { 'mathoid':
        ensure     => 'running',
        enable     => true,
        provider   => 'debian',
        hasrestart => true,
        require    => [
            File['/etc/mathoid/config.yaml'],
            File['/etc/systemd/system/mathoid.service'],
            Git::Clone['mathoid']
        ],
    }

    file { '/etc/systemd/system/restbase.service':
        ensure => present,
        source => 'puppet:///modules/mathoid/restbase.systemd',
        notify => Exec['mathoid reload systemd'],
    }

    service { 'restbase':
        ensure     => 'running',
        enable     => true,
        provider   => 'debian',
        hasrestart => true,
        require    => [
            File['/etc/restbase/config.yaml'],
            File['/etc/systemd/system/restbase.service'],
            Git::Clone['restbase']
        ],
    }
}
