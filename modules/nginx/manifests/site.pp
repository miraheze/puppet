# nginx::site
define nginx::site(
    Stdlib::Ensure $ensure   = present,
    Optional[String] $content  = undef,
    Stdlib::Sourceurl $source   = undef,
    Boolean $monitor  = true,
    Optional[Any] $notify_site = undef,
) {
    include ::nginx

    $basename = regsubst($title, '[\W_]', '-', 'G')

    if $notify_site != undef {
        file { "/etc/nginx/sites-available/${basename}":
            ensure  => $ensure,
            content => $content,
            source  => $source,
            require => Package['nginx'],
            notify  => $notify_site,
        }

        file { "/etc/nginx/sites-enabled/${basename}":
            ensure => link,
            target => "/etc/nginx/sites-available/${basename}",
            notify => $notify_site,
        }
    } else {
        file { "/etc/nginx/sites-available/${basename}":
            ensure  => $ensure,
            content => $content,
            source  => $source,
            require => Package['nginx'],
            notify  => Service['nginx'],
        }

        file { "/etc/nginx/sites-enabled/${basename}":
            ensure => link,
            target => "/etc/nginx/sites-available/${basename}",
            notify => Service['nginx'],
        }
    }

    if $monitor {
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
        if !defined(Icinga2::Custom::Services['HTTPS']) {
             icinga2::custom::services { 'HTTPS':
                 ensure        => 'absent',
                 check_command => 'check_http',
                 vars          => {
                     http_ssl  => true,
                 },
             }
         }
     }
}
