class role::jobrunner_haproxy (
    Hash $backends = lookup('jobrunner_haproxy::backends')
) {

    class { '::haproxy':
        config_content => epp('role/jobrunner_haproxy/haproxy.cfg.epp'),
    }

    haproxy::site { 'lb':
        ensure  => present,
        content => template('role/jobrunner_haproxy/lb.cfg.erb'),
    }

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
