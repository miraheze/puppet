# nginx::conf
#
define nginx::conf(
    VMlib::Ensure $ensure       = present,
    Optional[String] $content  = undef,
    VMlib::Sourceurl $source    = undef,
) {
    include ::nginx

    $basename = regsubst($title, '[\W_]', '-', 'G')

    file { "/etc/nginx/${basename}":
        ensure  => $ensure,
        content => $content,
        source  => $source,
        require => Package['nginx'],
        notify  => Service['nginx'],
    }
}
