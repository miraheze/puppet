# define a site config
define apache::site(
    $ensure    = present,
    $conf_type = 'sites',
    $priority  = 50,
    $content   = undef,
    $source    = undef,
    $replaces  = undef,
    $monitor   = true,
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
