# nginx::site
define nginx::site(
    $ensure   = present,
    $content  = undef,
    $source   = undef,
    $monitor  = true,
) {
    include ::nginx

    $basename = regsubst($title, '[\W_]', '-', 'G')

    file { "/etc/nginx/sites-available/${basename}":
        ensure  => $ensure,
        content => $content,
        source  => $source,
        require => Package['nginx'],
    }

    file { "/etc/nginx/sites-enabled/${basename}":
        ensure => link,
        target => "/etc/nginx/sites-available/${basename}",
        notify => Service['nginx'],
    }

    if $monitor {
        if hiera('base::monitoring::use_icinga2', false) {
            if !defined(Icinga2::Custom::Services['HTTPS']) {
                icinga2::custom::services { 'HTTPS':
                    check_command => 'check_http',
                    vars          => {
                        address  => "${::ipaddress}",
                        http_ssl  => true,
                    },
                }
            }
        } else {
            if !defined(Icinga::Service['HTTPS']) {
                icinga::service { 'HTTPS':
                    description   => 'HTTPS',
                    check_command => 'check_https',
                }
            }
        }
    } else {
        if hiera('base::monitoring::use_icinga2', false) {
            if !defined(Icinga2::Custom::Services['HTTPS']) {
                icinga2::custom::services { 'HTTPS':
                    ensure        => 'absent',
                    check_command => 'check_http',
                    vars          => {
                        http_ssl  => true,
                    },
                }
            }
        } else {
            if !defined(Icinga::Service['HTTPS']) {
                icinga::service { 'HTTPS':
                    ensure        => 'absent',
                    description   => 'HTTPS',
                    check_command => 'check_https',
                }
            }
        }
    }
}
