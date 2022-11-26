# class base::syslog
class base::syslog (
        Array[String] $syslog_host          = lookup('base::syslog::syslog_host', {'default_value' => []}),
        Integer $syslog_queue_size          = lookup('base::syslog::syslog_queue_size', {'default_value' => 50000}),
        Boolean $rsyslog_udp_localhost      = lookup('base::syslog::rsyslog_udp_localhost', {'default_value' => false}),
) {
        # We don't need persistant journals, all this did was cause slowness.
        file { '/var/log/journal' :
                ensure  => absent,
                recurse => true,
                force   => true,
                notify  => Service['systemd-journald'],
        }

        # Have to define this in order to restart it
        service { 'systemd-journald':
                ensure  => 'running',
        }

        include ::rsyslog

        file { '/etc/rsyslog.conf':
                ensure => present,
                source => 'puppet:///modules/base/rsyslog/rsyslog.conf',
                notify => Service['rsyslog'],
        }

        logrotate::conf { 'rsyslog':
                ensure  => present,
                source  => 'puppet:///modules/base/rsyslog/rsyslog.logrotate.conf',
                require => Class['rsyslog'],
        }

        if !empty( $syslog_host ) {
                ensure_packages('rsyslog-gnutls')

                ssl::wildcard { 'rsyslog wildcard': }

                rsyslog::conf { 'remote_syslog_rule':
                        content  => template('base/rsyslog/remote_syslog_rule.conf.erb'),
                        priority => 10,
                        require  => Ssl::Wildcard['rsyslog wildcard']
                }

                rsyslog::conf { 'remote_syslog_rule_parse_json':
                        content  => template('base/rsyslog/remote_syslog_rule_parse_json.conf.erb'),
                        priority => 10,
                        require  => Ssl::Wildcard['rsyslog wildcard']
                }

                rsyslog::conf { 'remote_syslog':
                        content  => template('base/rsyslog/remote_syslog.conf.erb'),
                        priority => 30,
                        require  => Ssl::Wildcard['rsyslog wildcard']
                }

                $ensure_enabled = $rsyslog_udp_localhost ? {
                        true    => present,
                        default => absent,
                }

                rsyslog::conf { 'rsyslog_udp_localhost':
                        ensure   => $ensure_enabled,
                        content  => template('base/rsyslog/rsyslog_udp_localhost.conf.erb'),
                        priority => 50,
                }

                if !defined(Rsyslog::Conf['mmjsonparse']) {
                        rsyslog::conf { 'mmjsonparse':
                                content  => 'module(load="mmjsonparse")',
                                priority => 00,
                        }
                }
        }
}
