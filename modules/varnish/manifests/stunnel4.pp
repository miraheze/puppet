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

    $backends.each | $name, $property | {
        if $name == 'phab121' {
            monitoring::nrpe { "Stunnel HTTP for ${name}":
                command => "/usr/lib/nagios/plugins/check_http -H localhost:${property['port']} -e 500",
            }
        } elsif $name == 'puppet111' {
            monitoring::nrpe { "Stunnel HTTP for ${name}":
                command => "/usr/lib/nagios/plugins/check_http -H localhost:${property['port']} -e 403",
            }
        } else {
            monitoring::nrpe { "Stunnel HTTP for ${name}":
                command => "/usr/lib/nagios/plugins/check_http -H localhost:${property['port']}",
            }
        }
    }
}
