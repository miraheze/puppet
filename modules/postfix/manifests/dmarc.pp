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

    service { 'opendmarc':
        ensure  => running,
        require => Package['opendmarc'],
    }
}
