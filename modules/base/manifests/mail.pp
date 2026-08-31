# A class to handle GENERIC server mail.
class base::mail (
    String $relayhost = lookup('base::mail::relayhost', {'default_value' => 'smtp-relay.gmail.com'}),
) {
    package { 'postfix':
        ensure => present,
    }

    package { 'exim4':
        ensure => absent,
    }

    file { '/etc/postfix/main.cf':
        ensure  => present,
        owner   => 'postfix',
        group   => 'postfix',
        content => epp('base/mail/main.epp', { 'relayhost' => $relayhost }),
        require => Package['postfix'],
        notify  => Service['postfix'],
    }

    service { 'postfix':
        ensure  => running,
        require => Package['postfix'],
    }

    mailalias { 'root':
        recipient => 'root@wikitide.net',
    }

    file { '/etc/mailname':
        ensure  => present,
        content => 'wikitide.net',
    }
}
