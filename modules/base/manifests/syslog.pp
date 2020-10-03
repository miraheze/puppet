# class base::syslog
class base::syslog (
        String $syslog_daemon   = 'rsyslog',
    ) {

    if $syslog_daemon == 'rsyslog' {
    	include ::rsyslog

        file { '/etc/rsyslog.conf':
            ensure => present,
            source => 'puppet:///modules/base/rsyslog/rsyslog.conf',
            notify => Service['rsyslog'],
        }
    } elsif $syslog_daemon == 'syslog_ng' {
        class { '::syslog_ng':
            manage_repo => false, # Is the default, but explicitly defined now
        }
    } else {
        warning('Invalid syslog_daemon selected for base::syslog.')
    }
}
