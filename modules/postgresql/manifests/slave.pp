# Class: postgresql::slave
#
# This class installs the server in a slave configuration
# It will create the replication user
#
# Parameters:
#   master_server
#       The FQDN of the master server to connect to
#   replication_pass
#       The password the replication user should use
#   ensure
#       Defaults to present
#   root_dir
#       See $postgresql::server::root_dir
#   use_ssl
#       Enable ssl for both clients and replication
#
# Actions:
#  Install/configure postgresql in a slave configuration
#
# Requires:
#
# Sample Usage:
#  class {'postgresql::slave':
#       master_server => 'mserver',
#       replication_pass => 'mypass',
#  }
#
class postgresql::slave(
    String $master_server,
    String $replication_pass,
    Optional[Array] $includes = [],
    Stdlib::Ensure $ensure = 'present',
    String $root_dir='/var/lib/postgresql',
    Boolean $use_ssl = false,
) {

    $pgversion = $facts['os']['distro']['codename'] ? {
        'bookworm' => 15,
        'trixie'   => 17,
    }

    $data_dir = "${root_dir}/${pgversion}/main"

    class { '::postgresql::server':
        ensure    => $ensure,
        pgversion => $pgversion,
        includes  => [ $includes, 'slave.conf'],
        root_dir  => $root_dir,
        use_ssl   => $use_ssl,
    }

    file { "/etc/postgresql/${pgversion}/main/slave.conf":
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/postgresql/slave.conf',
        require => Class['postgresql::server'],
    }

    file { "${data_dir}/recovery.conf":
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('postgresql/recovery.conf.erb'),
        before  => Class['postgresql::server'],
        require => Exec["pg_basebackup-${master_server}"],
    }

    # Let's sync once all our content from the master
    if $ensure == 'present' {
        exec { "pg_basebackup-${master_server}":
            environment => "PGPASSWORD=${replication_pass}",
            command     => "/usr/bin/pg_basebackup -X stream -D ${data_dir} -h ${master_server} -U replication -w",
            user        => 'postgres',
            unless      => "/usr/bin/test -f ${data_dir}/PG_VERSION",
            before      => Class['postgresql::server'],
        }
    }

    file { '/usr/bin/prometheus_postgresql_replication_lag':
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/postgresql/prometheus/postgresql_replication_lag.sh',
    }
}
