# @summary
#   Setup the reporting module for Icinga Web 2
#
# @param service_ensure
#   Manages if the reporting service should be stopped or running.
#
# @param service_enable
#   If set to true the reporting service will start on boot.
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
# @param mail
#   Mails are sent with this sender address.
#
class icinga::web::reporting (
  Enum['mysql', 'pgsql']    $db_type,
  Icinga::Secret            $db_pass,
  Stdlib::Ensure::Service   $service_ensure  = 'running',
  Boolean                   $service_enable  = true,
  Stdlib::Host              $db_host         = 'localhost',
  Optional[Stdlib::Port]    $db_port         = undef,
  String[1]                 $db_name         = 'reporting',
  String[1]                 $db_user         = 'reporting',
  Boolean                   $manage_database = false,
  Optional[String[1]]       $mail            = undef,
) {
  unless defined(Class['icinga::web::icingadb']) or defined(Class['icinga::web::monitoring']) {
    fail('Class icinga::web::icingadb or icinga::web::monitoring has to be declared before!')
  }

  icinga::prepare_web('Reporting')

  $icingaweb2_version = $icinga::web::icingaweb2_version
  $_db_charset        = $db_type ? {
    'mysql' => 'utf8mb4',
    default => 'UTF8',
  }

  #
  # Database
  #
  if $manage_database {
    class { 'icinga::web::reporting::database':
      db_type       => $db_type,
      db_name       => $db_name,
      db_user       => $db_user,
      db_pass       => $db_pass,
      web_instances => ['localhost'],
      before        => Class['icingaweb2::module::reporting'],
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

  class { 'icingaweb2::module::reporting':
    install_method => 'package',
    db_type        => $db_type,
    db_host        => $_db_host,
    db_port        => $db_port,
    db_name        => $db_name,
    db_username    => $db_user,
    db_password    => $db_pass,
    db_charset     => $_db_charset,
    import_schema  => lookup('icingaweb2::module::reporting::import_schema', undef, undef, true),
    mail           => $mail,
  }

  if versioncmp($icingaweb2_version, '4.0.0') < 0 {
    service { 'icinga-reporting':
      ensure  => $service_ensure,
      enable  => $service_enable,
      require => Class['icingaweb2::module::reporting'],
    }
  }

  if defined(Class['icinga::web::monitoring']) {
    class { 'icingaweb2::module::idoreports':
      install_method => 'package',
      import_schema  => true,
    }
  }
}
