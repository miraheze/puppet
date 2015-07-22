# nginx::site
#
define nginx::site(
    $ensure   = present,
    $content  = undef,
    $source   = undef,
    $ssl_cert = undef,
    $ca_cert  = 'GlobalSign',
) {
    include ::nginx

    $basename = regsubst($title, '[\W_]', '-', 'G')

    file { "/etc/nginx/sites-available/${basename}":
        ensure  => $ensure,
        content => $content,
        source  => $source,
    }

    file { "/etc/nginx/sites-enabled/${basename}":
        ensure => link,
        target => "/etc/nginx/sites-available/${basename}",
    }

    if $ssl_cert != undef {
        file { "/etc/ssl/certs/${ssl_cert}.crt":
            ensure => present,
            source => "puppet:///modules/base/ssl/${ssl_cert}.crt",
        }

        file { "/etc/ssl/private/${ssl_cert}.key":
            ensure => present,
            source => "puppet:///private/ssl/${ssl_cert}.key",
        }

        file { "/etc/ssl/certs/${ca_cert}.crt":
            ensure => present,
            source => "puppet:///modules/base/ssl/${ca_cert}.crt",
        }
    }
}
