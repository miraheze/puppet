# class: dovecot
class dovecot {
    include ssl::wildcard

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

    monitoring::services { 'IMAP':
        check_command => 'imap',
    }
}
