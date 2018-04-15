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
    $ensure           = 'present',
    $includes         = [],
    $listen_addresses = '*',
    $port             = '5432',
    $root_dir         = '/var/lib/postgresql',
    $use_ssl          = false,
    $pgversion        = '9.4',
) {

    package { [
        "postgresql-${pgversion}",
        "postgresql-${pgversion}-debversion",
        "postgresql-client-${pgversion}",
        "postgresql-contrib-${pgversion}",
        'libdbi-perl',
        'libdbd-pg-perl',
        'ptop',
        'check-postgres',
    ]:
        ensure => $ensure,
    }

    class { '::postgresql::dirs':
        ensure    => $ensure,
        pgversion => $pgversion,
        root_dir  => $root_dir,
    }

    $data_dir = "${root_dir}/${pgversion}/main"

    if $pgversion == '9.4' {
      $service_name = "postgresql@${pgversion}-main"
    } else {
      $service_name = 'postgresql'
    }

    exec { 'pgreload':
        command     => "/usr/bin/pg_ctlcluster ${pgversion} main reload",
        user        => 'postgres',
        refreshonly => true,
    }

    if $use_ssl {
        include ssl::wildcard

         file { "/etc/postgresql/${pgversion}/main/ssl":
             ensure => directory,
             owner  => 'postgres',
             group  => 'postgres',
         }

        file { "/etc/postgresql/${pgversion}/main/ssl/wildcard.miraheze.org.key":
            ensure  => 'present',
            source  => 'puppet:///ssl-keys/wildcard.miraheze.org.key',
            owner   => 'postgres',
            group   => 'postgres',
            mode    => '0600',
            require => File["/etc/postgresql/${pgversion}/main/ssl"],
	}

        file { "/etc/postgresql/${pgversion}/main/ssl.conf":
            ensure  => $ensure,
            source  => 'puppet:///modules/postgresql/ssl.conf',
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            before  => Service[$service_name],
            require => File["/etc/postgresql/${pgversion}/main/ssl/wildcard.miraheze.org.key"],
        }
    }

    service { $service_name:
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
