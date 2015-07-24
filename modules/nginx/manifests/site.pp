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
        file { "${conf_file} SSL cert":
            path   => "/etc/ssl/certs/${ssl_cert}.crt",
            ensure => present,
            source => "puppet:///modules/base/ssl/${ssl_cert}.crt",
        }

        file { "${conf_file} SSL key":
            path   => "/etc/ssl/private/${ssl_cert}.key",
            ensure => present,
            source => "puppet:///private/ssl/${ssl_cert}.key",
        }

        file { "${conf_file} ${ca_cert} cert":
            path   => "/etc/ssl/certs/${ca_cert}.crt",
            ensure => present,
            source => "puppet:///modules/base/ssl/${ca_cert}.crt",
        }
    }
}
