# nginx::site
define nginx::site(
    VMlib::Ensure $ensure     = present,
    Optional[String] $content = undef,
    VMlib::Sourceurl $source  = undef,
    Boolean $monitor          = true,
) {
    include ::nginx

    $basename = regsubst($title, '[\W_]', '-', 'G')

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

    $monitor_service = $monitor ? {
        true  => 'present',
        default => 'absent',
    }

    if !defined(Monitoring::Services['HTTPS']) {
        monitoring::services { 'HTTPS':
            ensure        => $monitor_service,
            check_command => 'check_http',
            vars          => {
                address6         => $facts['ipaddress6'],
                http_vhost       => $::fqdn,
                http_ssl         => true,
                http_ignore_body => true,
            },
        }
    }
}
