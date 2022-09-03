# @summary
#   Setup Director module for Icinga Web 2
#
# @param [Stdlib::Ensure::Service] service_ensure
#   Manages if the Director service should be stopped or running.
#
# @param [Boolean] service_enable
#   If set to true the Director service will start on boot.
#
# @param [Enum['mysql', 'pgsql']] db_type
#   Type of your database. Either `mysql` or `pgsql`.
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
# @param [String] endpoint
#   Endpoint object name of Icinga 2 API.
#
# @param [Boolean] manage_database
#   Create database and import schema.
#
# @param [Stdlib::Host] api_host
#   Icinga 2 API hostname.
#
# @param [String] api_user
#   Icinga 2 API username.
#
# @param [String] api_pass
#   Icinga 2 API password.
#
class icinga::web::director(
  String                                 $db_pass,
  String                                 $api_pass,
  String                                 $endpoint,
  Stdlib::Ensure::Service                $service_ensure  = 'running',
  Boolean                                $service_enable  = true,
  Enum['mysql', 'pgsql']                 $db_type         = 'mysql',
  Stdlib::Host                           $db_host         = 'localhost',
  Optional[Stdlib::Port]                 $db_port         = undef,
  String                                 $db_name         = 'director',
  String                                 $db_user         = 'director',
  Boolean                                $manage_database = false,
  Stdlib::Host                           $api_host        = 'localhost',
  String                                 $api_user        = 'director',
) {

  icinga::prepare_web('Director')

  unless $db_port {
    $_db_port = $db_type ? {
      'pgsql' => 5432,
      default => 3306,
    }
  } else {
    $_db_port = $db_port
  }

  #
  # Database
  #
  if $manage_database {
    class { '::icinga::web::director::database':
      db_type       => $db_type,
      db_name       => $db_name,
      db_user       => $db_user,
      db_pass       => $db_pass,
      web_instances => [ 'localhost' ],
      before        => Class['icingaweb2::module::director'],
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

  class { 'icingaweb2::module::director':
    install_method => 'package',
    db_type        => $db_type,
    db_host        => $_db_host,
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
    install_method   => 'package',
  }

  service { 'icinga-director':
    ensure  => $service_ensure,
    enable  => $service_enable,
    require => Class['icingaweb2::module::director'],
  }

}
