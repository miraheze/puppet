# DMARC
class postfix::dmarc {
    package { 'opendmarc':
        ensure => present,
    }

    file { '/etc/opendmarc.conf':
        ensure => present,
        owner  => 'opendmarc',
        source => 'puppet:///modules/postfix/opendmarc.conf',
    }
}
