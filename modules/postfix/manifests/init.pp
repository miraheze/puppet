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

    exec { '/usr/bin/newaliases':
        subscribe   => File['/etc/aliases'],
        refreshonly => true,
    }

    service { 'postfix':
        ensure    => running,
        require   => Package['postfix'],
        subscribe => [ File['/etc/postfix/main.cf'], File['/etc/postfix/master.cf'], ],
    }
}
