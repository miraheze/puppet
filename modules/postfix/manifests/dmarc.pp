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

    systemd::service { 'opendmarc':
        ensure  => present,
        content => systemd_template('opendmarc'),
        require => Package['opendmarc'],
    }
}
