# class: dovecot
class dovecot {
    ssl::wildcard { 'dovecot wildcard': }

    package { [ 'dovecot-core', 'dovecot-imapd', 'dovecot-ldap' ]:
        ensure => present,
    }

    file { '/etc/dovecot/dovecot.conf':
        ensure => present,
        source => 'puppet:///modules/dovecot/dovecot.conf',
        notify => Service['dovecot'],
    }

    $ldap_password = lookup('passwords::ldap_password')

    file { '/etc/dovecot/dovecot-ldap.conf':
        ensure  => present,
        content => template('dovecot/dovecot-ldap.conf'),
        notify  => Service['dovecot'],
    }

    service { 'dovecot':
        ensure  => 'running',
        require => Package['dovecot-core'],
    }

    monitoring::services { 'IMAP':
        check_command => 'imap',
    }
}
