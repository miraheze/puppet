# dns
class dns {
    # include prometheus::exporter::gdnsd

    package { 'bind9':
        ensure  => installed,
    }
    package { 'bind9-utils':
        ensure  => installed,
    }

    file { '/var/log/named':
        ensure => 'directory',
        owner  => 'bind',
        group  => 'bind',
        mode   => '0644',
    }

    git::clone { 'dns':
        ensure    => latest,
        directory => '/etc/bind',
        origin    => 'https://github.com/miraheze/dns',
        owner     => 'root',
        group     => 'root',
        before    => Package['bind9'],
        notify    => Exec['bind-syntax'],
    }

    file { '/usr/local/bin/check-dns-zones':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/dns/check-dns-zones.py',
        mode   => '0555',
    }

    exec { 'bind-syntax':
        command     => '/usr/local/bin/check-dns-zones',
        notify      => Service['named'],
        refreshonly => true,
    }

    service { 'named':
        ensure     => running,
        hasrestart => true,
        hasstatus  => true,
        require    => [ Package['bind9'], Exec['bind-syntax'], File['/var/log/named'] ],
    }

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'Auth DNS':
        check_command => 'check_dns_auth',
        vars          => {
            address6 => $address,
            host     => 'wikitide.net',
        },
    }
}
