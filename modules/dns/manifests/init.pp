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
        command => '/usr/sbin/gdnsd checkconf',
    }

    git::clone { 'dns':
        ensure    => latest,
        directory => '/etc/gdnsd',
        origin    => 'https://github.com/miraheze/dns.git',
        owner     => 'root',
        group     => 'root',
        before    => Package['gdnsd'],
        notify    => Service['gdnsd'],
    }
}
