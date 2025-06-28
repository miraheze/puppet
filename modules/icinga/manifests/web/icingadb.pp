# @summary
#   Setup IcingaDB module for the new backend.
#
# @param db_type
#   What kind of database type to use as backend.
#
# @param db_host
#   Database host to connect for the backenend.
#
# @param db_port
#   Port to connect the backend.
#
# @param db_name
#   Name of the database backend.
#
# @param db_user
#   Database backend user name.
#
# @param db_pass
#   Password to connect the backend.
#
# @param redis_host
#   Redis host to connect.
#
# @param redis_port
#   Connect `redis_host` om this port.
#
# @param redis_pass
#   Password for Redis connection.
#
# @param redis_primary_host
#   Alternative parameter to use for `redis_host`. Useful for high availability environments.
#
# @param redis_primary_port
#   Alternative parameter to use for `redis_port`. Useful for high availability environments.
#
# @param redis_primary_pass
#   Alternative parameter to use for `redis_passwod`. Useful for high availability environments.
#
# @param redis_secondary_host
#   Fallback Redis host to connect if the first one fails.
#
# @param redis_secondary_port
#   Port to connect on the fallback Redis server.
#
# @param redis_secondary_pass
#   Password for the second Redis server.
#
class icinga::web::icingadb (
  Icinga::Secret              $db_pass,
  Enum['mysql', 'pgsql']      $db_type,
  Stdlib::Host                $db_host              = 'localhost',
  Optional[Stdlib::Port]      $db_port              = undef,
  String[1]                   $db_name              = 'icingadb',
  String[1]                   $db_user              = 'icingadb',
  Stdlib::Host                $redis_host           = 'localhost',
  Optional[Stdlib::Port]      $redis_port           = undef,
  Optional[Icinga::Secret]    $redis_pass           = undef,
  Stdlib::Host                $redis_primary_host   = $redis_host,
  Optional[Stdlib::Port]      $redis_primary_port   = $redis_port,
  Optional[Icinga::Secret]    $redis_primary_pass   = $redis_pass,
  Optional[Stdlib::Host]      $redis_secondary_host = undef,
  Optional[Stdlib::Port]      $redis_secondary_port = undef,
  Optional[Icinga::Secret]    $redis_secondary_pass = undef,
) {
  require icinga::web

  $api_host = $icinga::web::api_host
  $api_user = $icinga::web::api_user
  $api_pass = $icinga::web::api_pass

  class { 'icingaweb2::module::icingadb':
    db_type                  => $db_type,
    db_host                  => $db_host,
    db_port                  => $db_port,
    db_name                  => $db_name,
    db_username              => $db_user,
    db_password              => $db_pass,
    db_charset               => 'UTF8',
    redis_primary_host       => $redis_primary_host,
    redis_primary_port       => $redis_primary_port,
    redis_primary_password   => $redis_primary_pass,
    redis_secondary_host     => $redis_secondary_host,
    redis_secondary_port     => $redis_secondary_port,
    redis_secondary_password => $redis_secondary_pass,
  }

  any2array($api_host).each |Stdlib::Host $host| {
    icingaweb2::module::icingadb::commandtransport { $host:
      host     => $host,
      username => $api_user,
      password => $api_pass,
    }
  }
}
