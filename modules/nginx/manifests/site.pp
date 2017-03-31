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
        if !defined(Icinga::Service['HTTP']) {
            icinga::service { 'HTTP':
                description   => 'HTTP',
                check_command => 'check_http',
            }
        }

        if !defined(Icinga::Service['HTTPS']) {
            icinga::service { 'HTTPS':
                description   => 'HTTPS',
                check_command => 'check_https',
            }
        }
    }
}
