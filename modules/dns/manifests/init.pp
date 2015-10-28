# dns
class dns {
    include ::apt
    
    apt::source { 'debian_stretch':
        comment  => 'Debian Stretch APT',
        location => 'http://ftp.debian.org/debian',
        release  => 'stretch',
        repos    => 'main contrib non-free',
    }

    # Debian Jessie has GDNSD 2.1, but we need 2.2 so we use stretch for this one
    file { '/etc/apt/preferences':
        ensure  => present,
        source  => 'puppet:///modules/dns/preferences.apt',
        require => Apt::Source['debian_stretch'],
        notify  => Exec['apt_update'],
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
