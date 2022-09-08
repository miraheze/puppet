# == Define: nginx::site
define nginx::site(
    VMlib::Ensure                $ensure  = 'present',
    Boolean                      $monitor = true,
    Optional[String]             $content = undef,
    Optional[Stdlib::Filesource] $source  = undef,
) {
    include nginx

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
