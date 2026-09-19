# class base::syslog
class base::syslog (
    Array[String] $syslog_host           = lookup('base::syslog::syslog_host', {'default_value' => []}),
    Integer       $syslog_queue_size     = lookup('base::syslog::syslog_queue_size', {'default_value' => 10000}),
    Boolean       $rsyslog_udp_localhost = lookup('base::syslog::rsyslog_udp_localhost', {'default_value' => false}),
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
        ensure => 'running',
    }

    include rsyslog

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

    if !empty($syslog_host) {
        stdlib::ensure_packages('rsyslog-gnutls')
        rsyslog::conf { 'remote_syslog_rule':
            content  => epp('base/rsyslog/remote_syslog_rule.conf.epp', {
                'syslog_host'       => $syslog_host,
                'syslog_queue_size' => $syslog_queue_size,
            }),
            priority => 10,
        }

        rsyslog::conf { 'remote_syslog_rule_parse_json':
            content  => epp('base/rsyslog/remote_syslog_rule_parse_json.conf.epp', {
                'syslog_host'       => $syslog_host,
                'syslog_queue_size' => $syslog_queue_size,
            }),
            priority => 10,
        }

        rsyslog::conf { 'remote_syslog':
            content  => epp('base/rsyslog/remote_syslog.conf.epp', {
                'syslog_host'       => $syslog_host,
                'syslog_queue_size' => $syslog_queue_size,
            }),
            priority => 30,
        }

        $ensure_enabled = $rsyslog_udp_localhost ? {
            true    => present,
            default => absent,
        }

        rsyslog::conf { 'rsyslog_udp_localhost':
            ensure   => $ensure_enabled,
            content  => epp('base/rsyslog/rsyslog_udp_localhost.conf.epp'),
            priority => 50,
        }

        if !defined(Rsyslog::Conf['mmjsonparse']) {
            rsyslog::conf { 'mmjsonparse':
                content  => 'module(load="mmjsonparse")',
                priority => 00,
            }
        }

        ssl::wildcard { 'rsyslog wildcard':
            notify => Service['rsyslog'],
        }
    }
}
