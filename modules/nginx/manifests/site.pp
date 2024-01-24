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

    $ensure_link = $ensure ? {
        'present' => link,
        default => 'absent',
    }
    file { "/etc/nginx/sites-enabled/${basename}":
        ensure => $ensure_link,
        target => "/etc/nginx/sites-available/${basename}",
        notify => Service['nginx'],
    }

    $monitor_service = $monitor ? {
        true  => 'present',
        default => 'absent',
    }

    if !defined(Monitoring::Services['HTTPS']) {
        if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
            $address = $facts['networking']['interfaces']['ens19']['ip']
            $address6 = undef
        } elsif ( $facts['networking']['interfaces']['ens18'] ) {
            $address = undef
            $address6 = $facts['networking']['interfaces']['ens18']['ip6']
        } else {
            $address = undef
            $address6 = $facts['networking']['ip6']
        }
        monitoring::services { 'HTTPS':
            ensure        => $monitor_service,
            check_command => 'check_curl',
            vars          => {
                address          => $address,
                address6         => $address6,
                http_vhost       => $facts['networking']['fqdn'],
                http_ssl         => true,
                http_ignore_body => true,
            },
        }
    }
}
