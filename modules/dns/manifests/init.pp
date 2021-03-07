# dns
class dns {
    include ::apt
    include prometheus::node_gdnsd

    if os_version('debian stretch') {
        apt::pin { 'debian_stretch_backports':
            priority   => 740,
            originator => 'Debian',
            release    => 'stretch-backports',
            packages   => 'gdnsd',
        }

        package { 'gdnsd':
            ensure  => installed,
            require => Apt::Pin['debian_stretch_backports'],
        }
    } else {
        package { 'gdnsd':
            ensure  => installed,
        }
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

    monitoring::services { 'Auth DNS':
        check_command => 'check_dns_auth',
        vars          => {
            host    => 'miraheze.org',
        },
    }

    monitoring::services { 'GDNSD Datacenters':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_gdnsd_datacenters',
        },
    }

    file { '/usr/share/GeoIP/GeoLite2-Country.mmdb':
        ensure => present,
        source => 'puppet:///private/geoip/GeoLite2-Country.mmdb',
        mode   => '0444',
    }
}
