# dns
class dns {
    include ::apt

    apt::source { 'debian_stretch':
        comment  => 'Debian Stretch APT',
        location => 'http://ftp.debian.org/debian',
        release  => 'stretch',
        repos    => 'main contrib non-free',
    }

    # Workaround for https://github.com/miraheze/puppet/issues/70
    apt::pin { 'debian_stable':
        priority => 995,
        release  => 'stable',
    }

    apt::pin { 'debian_stretch':
        priority   => 740,
        originator => 'Debian',
        release    => 'stretch',
        packages   => 'gdnsd',
    }

    package { 'gdnsd':
        ensure  => installed,
        require => File['/etc/apt/preferences'],
    }

    service { 'gdnsd':
        ensure     => running,
        hasrestart => true,
        hasstatus  => true,
        require    => [ Package['gdnsd'], Exec['gdnsd-syntax'] ],
    }

    exec { 'gdnsd-syntax':
        command     => '/usr/sbin/gdnsd checkconf',
        notify      => Service['gdnsd'],
        refreshonly => true,
    }

    git::clone { 'dns':
        ensure    => latest,
        directory => '/etc/gdnsd',
        origin    => 'https://github.com/miraheze/dns.git',
        owner     => 'root',
        group     => 'root',
        before    => Package['gdnsd'],
        notify    => Exec['gdnsd-syntax'],
    }

    file { '/usr/lib/nagios/plugins/check_gdnsd_datacenters':
        ensure => present,
        source => 'puppet:///modules/dns/check_gdnsd_datacenters.py',
        mode   => '0755',
    }

    icinga::service { 'auth_dns':
        description   => 'Auth DNS',
        check_command => 'check_dns_auth!miraheze.org',
    }

    icinga::service { 'gdnsd':
        description   => 'GDNSD Datacenters',
        check_command => 'check_nrpe_1arg!check_gdnsd_datacenters',
    }
}
