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

    systemd::service { 'stunnel4':
        ensure         => present,
        content        => systemd_template('stunnel4'),
        service_params => {
            enable  => true,
            require => [
                Package['stunnel4'],
                File['/etc/stunnel/mediawiki.conf'],
            ],
        }
    }

    logrotate::conf { 'stunnel4':
        ensure => present,
        source => 'puppet:///modules/varnish/stunnel/stunnel4.logrotate.conf',
    }

    $backends.each | $name, $property | {
        monitoring::nrpe { "Stunnel for ${name}":
            command => "/usr/lib/nagios/plugins/check_tcp -I localhost -p ${property['port']}",
        }
    }
}
