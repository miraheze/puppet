# @summary
#   Setup Director module for Icinga Web 2
#
# @param service_ensure
#   Manages if the Director service should be stopped or running.
#
# @param service_enable
#   If set to true the Director service will start on boot.
#
# @param db_type
#   Type of your database. Either `mysql` or `pgsql`.
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
# @param endpoint
#   Endpoint object name of Icinga 2 API.
#
# @param manage_database
#   Create database and import schema.
#
# @param api_host
#   Icinga 2 API hostname.
#
# @param api_user
#   Icinga 2 API username.
#
# @param api_pass
#   Icinga 2 API password.
#
class icinga::web::director (
  Icinga::Secret           $db_pass,
  Icinga::Secret           $api_pass,
  String[1]                $endpoint,
  Stdlib::Ensure::Service  $service_ensure  = 'running',
  Boolean                  $service_enable  = true,
  Enum['mysql', 'pgsql']   $db_type         = 'mysql',
  Stdlib::Host             $db_host         = 'localhost',
  Optional[Stdlib::Port]   $db_port         = undef,
  String[1]                $db_name         = 'director',
  String[1]                $db_user         = 'director',
  Boolean                  $manage_database = false,
  Stdlib::Host             $api_host        = 'localhost',
  String[1]                $api_user        = 'director',
) {
  icinga::prepare_web('Director')

  $icingaweb2_version = $icinga::web::icingaweb2_version

  #
  # Database
  #
  if $manage_database {
    class { 'icinga::web::director::database':
      db_type       => $db_type,
      db_name       => $db_name,
      db_user       => $db_user,
      db_pass       => $db_pass,
      web_instances => ['localhost'],
      before        => Class['icingaweb2::module::director'],
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

  class { 'icingaweb2::module::director':
    install_method => 'package',
    db_type        => $db_type,
    db_host        => $_db_host,
    db_port        => $db_port,
    db_name        => $db_name,
    db_username    => $db_user,
    db_password    => $db_pass,
    import_schema  => true,
    kickstart      => true,
    endpoint       => $endpoint,
    api_host       => $api_host,
    api_username   => $api_user,
    api_password   => $api_pass,
    db_charset     => 'UTF8',
  }

  class { 'icingaweb2::module::fileshipper':
    install_method => 'package',
  }

  # dirty hack around deamon restart
  # after pdo_psql is available
  Package[$icingaweb2::module::director::package_name, $icingaweb2::module::fileshipper::package_name]
  ~> exec { 'restart icinga-director daemon':
    path        => $facts['path'],
    command     => 'systemctl restart icinga-director',
    refreshonly => true,
    onlyif      => 'systemctl status icinga-director',
  }

  if versioncmp($icingaweb2_version, '4.0.0') < 0 {
    class { 'icingaweb2::module::director::service':
      ensure => $service_ensure,
      enable => $service_enable,
    }
  }
}
