# dns
class dns {
    include ::apt
    
    apt::source { 'debian_stretch':
        comment  => 'Debian Stretch APT',
        location => 'http://ftp.debian.org/debian',
        release  => 'stretch',
        repos    => 'main contrib non-free',
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
        require    => Package['gdnsd'],
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
