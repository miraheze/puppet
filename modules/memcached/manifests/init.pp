# == Class: memcached
#
# Memcached is a general-purpose, in-memory key-value store.
#
# === Parameters
#
# [*size*]
#   Instance size in megabytes (default: 2000).
#
# [*port*]
#   Port to listen on (default: 11000).
#
# [*ip*]
#   IP address to listen on (default: '0.0.0.0').
#
# [*version*]
#   Package version to install, or 'present' for any version
#   (default: 'present').
#
# [*growth_factor*]
#   Multiplier for computing the sizes of memory chunks that items
#   are stored in. Corresponds to memcached's -f parameter, and it
#   wil dictate the distribution of slab sizes.
#   Note: change the default only if you know what you are doing.
#   Default: 1.25
#
# [*growth_factor*]
#   This is the value of the smallest slab that memcached will use.
#   All the other slabs will be created using the growth_factor
#   parameter.
#   Note: change the default only if you know what you are doing.
#   Default: 48
#
# [*enable_tls*]
#   Configure mcrouter using TLS on external interfaces. This
#   parameter is only supported on memcached 1.6
#   Default: false
#
# [*ssl_cert*]
#   The public key used for SSL connections
#   Default: undef
#
# [*ssl_key*]
#   The public key used for SSL connections
#   Default: undef
#
# [*extra_options*]
#   A hash of additional command-line options and values.
#

# === Examples
#
#  class { '::memcached':
#    size => 100,
#    port => 11211,
#  }
#
class memcached(
    Integer                    $size          = 2000,
    Stdlib::Port               $port          = 11000,
    Stdlib::IP::Address        $ip            = '0.0.0.0',
    String                     $version       = 'present',
    Integer                    $min_slab_size = 48,
    Float                      $growth_factor = 1.25,
    Hash[String, Any]          $extra_options = {},
    Boolean                    $enable_tls    = false,
    Optional[Stdlib::Unixpath] $ssl_cert      = undef,
    Optional[Stdlib::Unixpath] $ssl_key       = undef,
) {

    if $enable_tls and (!$ssl_key or !$ssl_key) {
        fail('you must provide ssl_cert and ssl_key if you enable_tls')
    }

    if ($ip == '0.0.0.0' and $enable_tls and !$enable_tls_localhost) {
        # if the ip is 0.0.0.0, indicating all ipv4 interfaces,
        # then we need to split theses addresses out to ensure we
        # have notls on localhost
        $listen = [$facts['networking']['ip'], 'notls:localhost']
    } else {
        $listen = [$ip, '::']
    }

    package { 'memcached':
        ensure => $version,
        before => Service['memcached'],
    }

    systemd::service { 'memcached':
        ensure  => present,
        content => systemd_template('memcached'),
    }

    monitoring::services { 'memcached':
        check_command => 'tcp',
        docs          => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#Memcached',
        vars          => {
            tcp_port    => $port,
        }
    }
}
