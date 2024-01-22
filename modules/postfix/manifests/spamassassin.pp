# class: spamassassin
class postfix::spamassassin {
    $packages = [
        'spamd',
        'spamc'
    ]

    package { $packages:
        ensure => present,
    }

    service { 'spamd':
        ensure => running,
    }

    file { '/etc/spamassassin/local.cf':
        ensure => present,
        source => 'puppet:///modules/postfix/spamassassin/local.cf',
        notify => Service['spamd'],
    }
}
