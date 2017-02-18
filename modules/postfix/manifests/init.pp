# class: postfix
class postfix {
    package { 'postfix':
        ensure => present,
    }

    file { '/etc/postfix/main.cf':
        ensure => present,
        source => 'puppet:///modules/postfix/main.cf',
    }

    file { '/etc/postfix/master.cf':
        ensure => present,
        source => 'puppet:///modules/postfix/master.cf',
    }

    file { '/etc/aliases':
        ensure => present,
        source => 'puppet:///modules/postfix/aliases',
    }

    file { '/etc/virtual':
        ensure => present,
        source => 'puppet:///modules/postfix/virtual',
    }

    exec { '/usr/bin/newaliases':
        subscribe   => [ File['/etc/aliases'], File['/etc/virtual'], ],
        refreshonly => true,
    }

    service { 'postfix':
        ensure    => running,
        require   => Package['postfix'],
        subscribe => [ File['/etc/postfix/main.cf'], File['/etc/postfix/master.cf'], ],
    }

    icinga::service { 'smtp':
        description   => 'SMTP',
        check_command => 'check_smtp',
    }
}
