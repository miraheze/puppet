# @summary
#   Setup VSphereDB module for Icinga Web 2
#
# @param [Stdlib::Ensure::Service] service_ensure
#   Manages if the VSphereDB service should be stopped or running.
#
# @param [Boolean] service_enable
#   If set to true the VSphereDB service will start on boot.
#
# @param [Enum['mysql']] db_type
#   Type of your database. At the moment only `mysql` is supported by the Icinga team.
#
# @param [Stdlib::Host] db_host
#   Hostname of the database.
#
# @param [Optional[Stdlib::Port]] db_port
#   Port of the database.
#
# @param [String] db_name
#   Name of the database.
#
# @param [String] db_user
#   Username for DB connection.
#
# @param [String] db_pass
#   Password for DB connection.
#
# @param [Boolean] manage_database
#   Create database and import schema.
#
class icinga::web::vspheredb(
  String                                 $db_pass,
  Stdlib::Ensure::Service                $service_ensure  = 'running',
  Boolean                                $service_enable  = true,
  Enum['mysql']                          $db_type         = 'mysql',
  Stdlib::Host                           $db_host         = 'localhost',
  Optional[Stdlib::Port]                 $db_port         = undef,
  String                                 $db_name         = 'vspheredb',
  String                                 $db_user         = 'vspheredb',
  Boolean                                $manage_database = false,
) {

  icinga::prepare_web('VSphereDB')

  unless $db_port {
    $_db_port = $db_type ? {
      'pgsql' => 5432,
      default => 3306,
    }
  } else {
    $_db_port = $db_port
  }

  $_db_charset = $db_type ? {
    'mysql' => 'utf8mb4',
    default => 'UTF8',
  }

  #
  # Database
  #
  if $manage_database {
    class { '::icinga::web::vspheredb::database':
      db_type       => $db_type,
      db_name       => $db_name,
      db_user       => $db_user,
      db_pass       => $db_pass,
      web_instances => [ 'localhost' ],
      before        => Class['icingaweb2::module::vspheredb'],
    }
    $_db_host = 'localhost'
  } else {
    if $db_type != 'pgsql' {
      include ::mysql::client
    } else {
      include ::postgresql::client
    }
    $_db_host = $db_host
  }

  class { 'icingaweb2::module::vspheredb':
    install_method => 'package',
    db_type        => $db_type,
    db_host        => $_db_host,
    db_name        => $db_name,
    db_username    => $db_user,
    db_password    => $db_pass,
    db_charset     => $_db_charset,
    import_schema  => lookup('icingaweb2::module::vspheredb::import_schema', undef, undef, true),
  }

  service { 'icinga-vspheredb':
    ensure  => $service_ensure,
    enable  => $service_enable,
    require => Class['icingaweb2::module::vspheredb'],
  }

}
