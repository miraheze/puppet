class role::jobrunner_haproxy (
    Hash $backends = lookup('jobrunner_haproxy::backends')
) {

    class { '::haproxy':
        config_content => template('role/jobrunner_haproxy/haproxy.cfg.erb'),
    }

    haproxy::site { 'lb':
        ensure  => present,
        content => template('role/jobrunner_haproxy/lb.cfg.erb'),
    }

    rsyslog::conf { 'haproxy':
        priority => 20,
        content  => template('role/jobrunner_haproxy/haproxy.rsyslog.conf.erb'),
    }

    ['9007', '9008', '9009'].each |String $port| {
        monitoring::nrpe { "Haproxy backend for ${name}":
            command => "/usr/lib/nagios/plugins/check_tcp -H localhost -p ${port}",
        }
    }
}
