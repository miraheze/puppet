# define a site config
define apache::site(
    $ensure    = present,
    $conf_type = 'sites',
    $priority  = 50,
    $content   = undef,
    $source    = undef,
    $replaces  = undef,
    $ssl_cert  = undef,
    $ca_cert   = 'GlobalSign',
) {
    include ::apache

    if $source == undef and $content == undef  {
        fail('you must provide either "source" or "content"')
    }

    if $source != undef and $content != undef  {
        fail('"source" and "content" are mutually exclusive')
    }

    $title_safe  = regsubst($title, '[\W_]', '-', 'G')
    $file_ext    = $conf_type ? { env => 'sh', default => 'conf' }
    $conf_file   = sprintf('%02d-%s.%s', $priority, $title_safe, $file_ext)
    $content_formatted = $content ? {
        undef   => undef,
        default => regsubst($content, "\n?$", "\n"),
    }

    file { "/etc/apache2/${conf_type}-available/${conf_file}":
        ensure  => $ensure,
        content => $content_formatted,
        source  => $source,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['apache2'],
    }

    file { "/etc/apache2/${conf_type}-enabled/${conf_file}":
        ensure => link,
        target => "/etc/apache2/${conf_type}-available/${conf_file}",
        notify => Service['apache2'],
    }

    if $replaces != undef {
        file { "${title_safe}_${replaces}":
            ensure => absent,
            path   => "/etc/apache2/${replaces}",
        }
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
