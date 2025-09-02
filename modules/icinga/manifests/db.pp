# @param db_type
#   Choose wether MySQL or PostgreSQL as backend for historical data.
#
# @param db_host
#   Database server.
#
# @param db_port
#   Port to connect the database.
#
# @param db_name
#   The IcingaDB database.
#
# @param db_user
#   User to connect the database.
#
# @param db_pass
#   Passwort to login into database.
#
# @param manage_database
#   Install and create database on localhost.
#
# @param db_accesses
#   List of hosts with access to the database, e.g. host running Icinga Web 2.
#   Omly valid if `manage_database` is `true`.
#
# @param redis_host
#   Redis host to connect.
#
# @param redis_bind
#   When Redis runs on a differnt host than Icinga, here the listining interfaces
#   have to be set.
#
# @param redis_port
#   Port for Redis listening.
#
# @param redis_pass
#   Password to authenticate against Redis.
#
# @param manage_redis
#   Install and create the IcingaDB Redis service on localhost.
#
# @param manage_feature
#   If you wanna manage the Icinga 2 feature for the IcingaDB, set this to `true`.
#   This only make sense when an Icinga 2 Server is running on the same host.
#
class icinga::db (
  Icinga::Secret                        $db_pass,
  Enum['mysql', 'pgsql']                $db_type,
  Stdlib::Host                          $db_host         = 'localhost',
  Optional[Stdlib::Port]                $db_port         = undef,
  String[1]                             $db_name         = 'icingadb',
  String[1]                             $db_user         = 'icingadb',
  Boolean                               $manage_database = false,
  Array[Stdlib::Host]                   $db_accesses     = [],
  Stdlib::Host                          $redis_host      = 'localhost',
  Optional[Array[Stdlib::Host]]         $redis_bind      = undef,
  Optional[Stdlib::Port]                $redis_port      = undef,
  Optional[Icinga::Secret]              $redis_pass      = undef,
  Boolean                               $manage_redis    = true,
  Boolean                               $manage_feature  = true,
) {
  if $manage_database {
    $_db_host = 'localhost'

    class { 'icinga::db::database':
      db_type          => $db_type,
      db_name          => $db_name,
      db_user          => $db_user,
      db_pass          => $db_pass,
      access_instances => concat($db_accesses, ['localhost']),
      before           => Class['icingadb'],
    }
  } else {
    $_db_host = $db_host

    if $db_type != 'pgsql' {
      include mysql::client
    } else {
      include postgresql::client
    }
  }

  if $manage_redis {
    $_redis_host = 'localhost'

    class { 'icingadb::redis':
      bind        => $redis_bind,
      port        => $redis_port,
      requirepass => $redis_pass,
      before      => Class['icingadb'],
    }
  } else {
    $_redis_host = $redis_host
  }

  class { 'icingadb':
    db_type        => $db_type,
    db_host        => $_db_host,
    db_port        => $db_port,
    db_name        => $db_name,
    db_username    => $db_user,
    db_password    => $db_pass,
    import_schema  => true,
    redis_host     => $_redis_host,
    redis_port     => $redis_port,
    redis_password => $redis_pass,
  }

  if $manage_feature {
    class { 'icinga2::feature::icingadb':
      host     => $_redis_host,
      port     => $redis_port,
      password => $redis_pass,
    }
  }
}
