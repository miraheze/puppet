# == Define: nginx::site
#
# Provisions an Nginx vhost. Like file resources, this resource type takes
# either a 'content' parameter with a string literal value or 'source'
# parameter with a Puppet file reference. The resource title is used as the
# site name.
#
# === Parameters
#
# [*content*]
#   The Nginx site configuration as a string literal.
#   Either this or 'source' must be set.
#
# [*source*]
#   The Nginx site configuration as a Puppet file reference.
#   Either this or 'content' must be set.
#
# [*ensure*]
#   'present' or 'absent'; whether the site configuration is
#   installed or removed in sites-available/
#
# [*monitor*]
#   Boolean; Whether HTTPS monitoring should be enabled for the site.
#
# === Examples
#
#  nginx::site { 'mediawiki':
#    content => template('mediawiki/mediawiki.conf.erb'),
#  }
#
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
