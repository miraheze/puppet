# class: dovecot
class dovecot {
    package { [ 'dovecot-core', 'dovecot-imapd' ]:
        ensure => present,
    }

    file { '/etc/dovecot/dovecot.conf':
        ensure => present,
        source => 'puppet:///modules/dovecot/dovecot.conf',
    }

    service { 'dovecot':
        ensure    => 'running',
        require   => Package['dovecot-core'],
        subscribe => File['/etc/dovecot/dovecot.conf'],
    }

    icinga::service { 'imap':
        description   => 'IMAP',
        check_command => 'check_imap',
    }
}
