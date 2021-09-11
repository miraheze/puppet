# class: varnish::stunnel4
class varnish::stunnel4 {
    ensure_packages('stunnel4')

    file { '/etc/default/stunnel4':
        ensure  => present,
        source  => 'puppet:///modules/varnish/stunnel/stunnel.default',
        notify  => Service['stunnel4'],
        require => Package['stunnel4'],
    }

    file { '/etc/stunnel/mediawiki.conf':
        ensure  => present,
        source  => 'puppet:///modules/varnish/stunnel/stunnel.conf',
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

    ['mon2', 'mw8', 'mw9', 'mw10', 'mw11', 'mw12', 'mw13'].each |$host| {
        monitoring::services { "Stunnel Http for ${host}":
            check_command => 'nrpe',
            vars          => {
                nrpe_command => "check_stunnel_${host}",
                nrpe_timeout => '10s',
            },
        }
    }
}
