# @summary
#   Configure IDO Backend.
#
# @param db_pass
#   Password to connect the database.
#
# @param db_type
#   What kind of database type to use.
#
# @param db_host
#   Database host to connect.
#
# @param db_port
#   Port to connect. Only affects for connection to remote database hosts.
#
# @param db_name
#   Name of the database.
#
# @param db_user
#   Database user name.
#
# @param manage_database
#   Create database and import schema.
#
# @param enable_ha
#   Enable HA feature for database.
#
class icinga::ido (
  Icinga::Secret                         $db_pass,
  Enum['mysql','pgsql']                  $db_type         = 'mysql',
  Stdlib::Host                           $db_host         = 'localhost',
  Optional[Stdlib::Port]                 $db_port         = undef,
  String[1]                              $db_name         = 'icinga2',
  String[1]                              $db_user         = 'icinga2',
  Boolean                                $manage_database = false,
  Boolean                                $enable_ha       = false,
) {
  unless $db_port {
    $_db_port = $db_type ? {
      'pgsql' => 5432,
      default => 3306,
    }
  } else {
    $_db_port = $db_port
  }

  if $db_type != 'pgsql' {
    include mysql::client
  } else {
    include postgresql::client
  }

  if $manage_database {
    class { 'icinga::ido::database':
      db_type       => $db_type,
      db_name       => $db_name,
      db_user       => $db_user,
      db_pass       => $db_pass,
      ido_instances => [$db_host],
      before        => Class["icinga2::feature::ido${db_type}"],
    }
  }
#  } else {
#    if $db_type != 'pgsql' {
#      include mysql::client
#    } else {
#      include postgresql::client
#    }
#  }

  if $facts['kernel'] == 'linux' {
    $ido_package_name = $db_type ? {
      'mysql' => $icinga2::globals::ido_mysql_package_name,
      'pgsql' => $icinga2::globals::ido_pgsql_package_name,
    }

    if $facts['os']['family'] == 'debian' {
      ensure_resources('file', { '/etc/dbconfig-common' => { ensure => directory, owner => 'root', group => 'root' } })
      file { "/etc/dbconfig-common/${ido_package_name}.conf":
        ensure  => file,
        content => "dbc_install='false'\ndbc_upgrade='false'\ndbc_remove='false'\n",
        mode    => '0600',
        before  => Package[$ido_package_name],
      }
    } # Debian

    package { $ido_package_name:
      ensure => installed,
      before => Class["icinga2::feature::ido${db_type}"],
    }
  } # Linux

  class { "icinga2::feature::ido${db_type}":
    host          => $db_host,
    port          => $_db_port,
    database      => $db_name,
    user          => $db_user,
    password      => $db_pass,
    import_schema => true,
    enable_ha     => $enable_ha,
  }
}
