# class base::rsyslog
class base::rsyslog {
    service { 'rsyslog':
        ensure => running,
    }

    file { '/etc/rsyslog.conf':
        ensure => present,
        source => 'puppet:///modules/base/rsyslog/rsyslog.conf',
        notify => Service['rsyslog'],
    }
}
