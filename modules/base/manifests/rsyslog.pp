# class base::rsyslog
class base::rsyslog {
	include ::rsyslog

    file { '/etc/rsyslog.conf':
        ensure => present,
        source => 'puppet:///modules/base/rsyslog/rsyslog.conf',
        notify => Service['rsyslog'],
    }
}
