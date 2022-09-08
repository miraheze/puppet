# class: postfix
class postfix {
    $packages = [
        'postfix',
        'postfix-ldap',
        'postfix-pcre',
    ]

    ssl::wildcard { 'postfix wildcard': }

    package { $packages:
        ensure => present,
    }

    file { '/etc/postfix/main.cf':
        ensure => present,
        source => 'puppet:///modules/postfix/main.cf',
        notify => Service['postfix'],
    }

    file { '/etc/postfix/master.cf':
        ensure => present,
        source => 'puppet:///modules/postfix/master.cf',
        notify => Service['postfix'],
    }

    file { '/etc/postfix/ldap':
        ensure => directory,
    }

    $ldap_password = lookup('passwords::ldap_password')

    file { '/etc/postfix/ldap/smtpd_sender_login_maps':
        ensure  => present,
        content => template('postfix/smtpd_sender_login_maps'),
        notify  => Service['postfix'],
    }

    file { '/etc/postfix/ldap/virtual_alias_maps':
        ensure  => present,
        content => template('postfix/virtual_alias_maps'),
        notify  => Service['postfix'],
    }

    file { '/etc/postfix/ldap/virtual_mailbox_maps':
        ensure  => present,
        content => template('postfix/virtual_mailbox_maps'),
        notify  => Service['postfix'],
    }

    file { '/etc/postfix/ldap/virtual_alias_domains':
        ensure  => present,
        content => template('postfix/virtual_alias_domains'),
        notify  => Service['postfix'],
    }

    file { '/etc/postfix/ldap/virtual_alias_groups':
        ensure  => present,
        content => template('postfix/virtual_alias_groups'),
        notify  => Service['postfix'],
    }

    service { 'postfix':
        ensure  => running,
        require => Package['postfix'],
    }

    monitoring::services { 'SMTP':
        check_command => 'smtp',
    }
}
