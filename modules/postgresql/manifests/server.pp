# Class: postgresql::server
#
# This class installs postgresql packages, standard configuration
#
# Parameters:
#   ensure
#       Defaults to present
#   includes
#       An array of files that will be included in the config. It is
#       the caller's responsibility to provide these
#   root_dir
#       The root directory for postgresql data. The actual directory will be
#       "${root_dir}/${pgversion}/main".
#   use_ssl
#       Enable ssl
#
# Actions:
#  Install/configure postgresql
#
# Requires:
#
# Sample Usage:
#  include postgresql::server
#
class postgresql::server(
    VMlib::Ensure $ensure = 'present',
    Optional[Array] $includes = [],
    String $listen_addresses = '*',
    String $port             = '5432',
    String $root_dir         = '/var/lib/postgresql',
    Boolean $use_ssl          = false,
    String $pgversion        = '9.6',
) {

    ensure_packages(
        [
            "postgresql-${pgversion}",
            "postgresql-${pgversion}-debversion",
            "postgresql-client-${pgversion}",
            "postgresql-contrib-${pgversion}",
            'check-postgres',
            'libdbd-pg-perl',
            'libdbi-perl',
        ],
        {
            ensure => $ensure,
        },
    )

    ensure_packages('pgtop')

    class { '::postgresql::dirs':
        ensure    => $ensure,
        pgversion => $pgversion,
        root_dir  => $root_dir,
    }

    $data_dir = "${root_dir}/${pgversion}/main"

    exec { 'pgreload':
        command     => "/usr/bin/pg_ctlcluster ${pgversion} main reload",
        user        => 'postgres',
        refreshonly => true,
    }

    if $use_ssl {
        ssl::wildcard { 'postgresql wildcard': }

         file { "/etc/postgresql/${pgversion}/main/ssl":
             ensure => directory,
             owner  => 'postgres',
             group  => 'postgres',
         }

        file { "/etc/postgresql/${pgversion}/main/ssl/wildcard.miraheze.org.key":
            ensure  => 'present',
            source  => 'puppet:///ssl-keys/wildcard.miraheze.org-2020-2.key',
            owner   => 'postgres',
            group   => 'postgres',
            mode    => '0600',
            require => File["/etc/postgresql/${pgversion}/main/ssl"],
        }

        file { "/etc/postgresql/${pgversion}/main/ssl.conf":
            ensure  => $ensure,
            content => template('postgresql/ssl.conf.erb'),
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            before  => Service['postgresql'],
            require => File["/etc/postgresql/${pgversion}/main/ssl/wildcard.miraheze.org.key"],
        }
    }

    service { 'postgresql':
        ensure  => ensure_service($ensure),
    }

    file { "/etc/postgresql/${pgversion}/main/postgresql.conf":
        ensure  => $ensure,
        content => template('postgresql/postgresql.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
    }
}
