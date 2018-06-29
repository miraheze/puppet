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

    file { '/etc/virtual_domains':
        ensure => present,
        source => 'puppet:///modules/postfix/virtual_domains',
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

    if hiera('base::monitoring::user_icinga2', false) {
        icinga2::object::service { 'SMTP':
            check_command => 'smtp',
        }
    } else {
        icinga::service { 'smtp':
            description   => 'SMTP',
            check_command => 'check_smtp',
        }
    }
}
