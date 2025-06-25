# @summary
#   Setup Monitoring module for the IDO backend.
#
# @param db_type
#   What kind of database type to use as IDO backend.
#
# @param db_host
#   Database host to connect for the IDO backenend.
#
# @param db_port
#   Port to connect the IDO backend.
#
# @param db_name
#   Name of the IDO database backend.
#
# @param db_user
#   IDO database backend user name.
#
# @param db_pass
#   Pasword to connect the IDO backend.
#
class icinga::web::monitoring (
  Icinga::Secret                       $db_pass,
  Enum['mysql', 'pgsql']               $db_type    = 'mysql',
  Stdlib::Host                         $db_host    = 'localhost',
  Optional[Stdlib::Port::Unprivileged] $db_port    = undef,
  String[1]                            $db_name    = 'icinga2',
  String[1]                            $db_user    = 'icinga2',
) {
  require icinga::web

  $api_host = $icinga::web::api_host
  $api_user = $icinga::web::api_user
  $api_pass = $icinga::web::api_pass

  class { 'icingaweb2::module::monitoring':
    ido_type        => $db_type,
    ido_host        => $db_host,
    ido_port        => $db_port,
    ido_db_name     => $db_name,
    ido_db_username => $db_user,
    ido_db_password => $db_pass,
  }

  any2array($api_host).each |Stdlib::Host $host| {
    icingaweb2::module::monitoring::commandtransport { $host:
      transport => 'api',
      host      => $host,
      username  => $api_user,
      password  => $api_pass,
    }
  }
}
