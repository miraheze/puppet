class role::jobrunner_haproxy (
    Hash $backends = lookup('jobrunner_haproxy::backends'),
    Integer $agent_port = lookup('haproxy::lb_agent::port', {'default_value' => 9590}),
    String $timeout_queue = lookup('jobrunner_haproxy::timeout_queue', {'default_value' => '600s'}),
) {

    class { 'haproxy':
        config_content => epp('role/jobrunner_haproxy/haproxy.cfg.epp'),
    }

    haproxy::site { 'lb':
        ensure  => present,
        content => template('role/jobrunner_haproxy/lb.cfg.erb'),
    }

    include haproxy::lb_ctl
    include haproxy::lb_monitoring

    rsyslog::conf { 'haproxy':
        priority => 20,
        content  => epp('role/jobrunner_haproxy/haproxy.rsyslog.conf.epp'),
    }

    ['9007', '9008', '9009'].each |String $port| {
        monitoring::nrpe { "Haproxy backend for localhost:${port}":
            command => "/usr/lib/nagios/plugins/check_tcp -H localhost -p ${port}",
        }
    }
}
