# DMARC
class postfix::dmarc {
    package { 'opendmarc':
        ensure => present,
    }

    file { '/etc/opendmarc.conf':
        ensure => present,
        owner  => 'opendmarc',
        group  => 'opendmarc',
        source => 'puppet:///modules/postfix/opendmarc.conf',
        notify => Service['opendmarc'],
    }

    file { '/etc/default/opendmarc':
        ensure => present,
        source => 'puppet:///modules/postfix/opendmarc',
    }

    exec { 'opendmarc reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/lib/systemd/system/opendmarc.service':
        ensure => present,
        source => 'puppet:///modules/postfix/opendmarc.systemd',
        notify => Exec['opendmarc reload systemd'],
    }

    service { 'opendmarc':
        ensure  => 'running',
        require => [Package['opendmarc'], File['/etc/systemd/system/opendmarc.service']],
    }
}
