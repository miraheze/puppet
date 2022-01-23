# class: varnish::stunnel4
class varnish::stunnel4 {
    ensure_packages('stunnel4')

    file { '/etc/default/stunnel4':
        ensure  => present,
        source  => 'puppet:///modules/varnish/stunnel/stunnel.default',
        notify  => Service['stunnel4'],
        require => Package['stunnel4'],
    }

    $backends = lookup('varnish::backends')

    file { '/etc/stunnel/mediawiki.conf':
        ensure  => present,
        content => template('varnish/stunnel.conf'),
        notify  => Service['stunnel4'],
        require => Package['stunnel4'],
    }

    service { 'stunnel4':
        ensure  => 'running',
        require => Package['stunnel4'],
    }

    logrotate::conf { 'stunnel4':
        ensure => present,
        source => 'puppet:///modules/varnish/stunnel/stunnel4.logrotate.conf',
    }

    $backends.each_pair | $name, $property | {
        monitoring::services { "Stunnel HTTP for ${name}":
            check_command => 'nrpe',
            vars          => {
                nrpe_command => "check_stunnel_${name}",
                nrpe_timeout => '10s',
            },
        }
    }
}
