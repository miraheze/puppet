# @summary
#   Setup the x509 module for Icinga Web 2
#
# @param service_ensure
#   Manages if the x509 service should be stopped or running.
#
# @param service_enable
#   If set to true the x509 service will start on boot.
#
# @param db_type
#   Type of your database.
#
# @param db_host
#   Hostname of the database.
#
# @param db_port
#   Port of the database.
#
# @param db_name
#   Name of the database.
#
# @param db_user
#   Username for DB connection.
#
# @param db_pass
#   Password for DB connection.
#
# @param manage_database
#   Create database and import schema.
#
class icinga::web::x509 (
  Enum['mysql', 'pgsql']    $db_type,
  Icinga::Secret            $db_pass,
  Stdlib::Ensure::Service   $service_ensure  = 'running',
  Boolean                   $service_enable  = true,
  Stdlib::Host              $db_host         = 'localhost',
  Optional[Stdlib::Port]    $db_port         = undef,
  String[1]                 $db_name         = 'x509',
  String[1]                 $db_user         = 'x509',
  Boolean                   $manage_database = false,
) {
  unless defined(Class['icinga::web::icingadb']) or defined(Class['icinga::web::monitoring']) {
    fail('Class icinga::web::icingadb or icinga::web::monitoring has to be declared before!')
  }

  $icingaweb2_version = $icinga::web::icingaweb2_version
  $_db_charset        = $db_type ? {
    'mysql' => 'utf8mb4',
    default => 'UTF8',
  }

  #
  # Database
  #
  if $manage_database {
    class { 'icinga::web::x509::database':
      db_type       => $db_type,
      db_name       => $db_name,
      db_user       => $db_user,
      db_pass       => $db_pass,
      web_instances => ['localhost'],
      before        => Class['icingaweb2::module::x509'],
    }
    $_db_host = 'localhost'
  } else {
    if $db_type != 'pgsql' {
      include mysql::client
    } else {
      include postgresql::client
    }
    $_db_host = $db_host
  }

  class { 'icingaweb2::module::x509':
    install_method => 'package',
    db_type        => $db_type,
    db_host        => $_db_host,
    db_port        => $db_port,
    db_name        => $db_name,
    db_username    => $db_user,
    db_password    => $db_pass,
    db_charset     => $_db_charset,
    import_schema  => lookup('icingaweb2::module::x509::import_schema', undef, undef, true),
  }

  if versioncmp($icingaweb2_version, '4.0.0') < 0 {
    service { 'icinga-x509':
      ensure  => $service_ensure,
      enable  => $service_enable,
      require => Class['icingaweb2::module::x509'],
    }
  }
}
