# @summary
#   Setup Director database.
#
# @param db_type
#   What kind of database type to use.
#
# @param web_instances
#   List of Hosts to allow write access to the database.
#   Usually an Icinga Web 2 instance.
#
# @param db_pass
#   Password to connect the database.
#
# @param db_name
#   Name of the database.
#
# @param db_user
#   Database user name.
#
# @param tls
#   Access only for TLS encrypted connections. Authentication via `password` or `cert`,
#   value `true` means password auth.
#
class icinga::web::director::database (
  Enum['mysql','pgsql']      $db_type,
  Array[Stdlib::Host]        $web_instances,
  Icinga::Secret             $db_pass,
  String[1]                  $db_user = 'director',
  String[1]                  $db_name = 'director',
  Variant[Boolean,
  Enum['password','cert']]   $tls      = false,
) {
  if $db_type == 'mysql' {
    $_encoding  = 'utf8mb4'
    $_collation = 'utf8mb4_bin'
  } else {
    $_encoding  = 'UTF8'
    $_collation = undef
  }

  icinga::database { "${db_type}-${db_name}":
    db_type          => $db_type,
    db_name          => $db_name,
    db_user          => $db_user,
    db_pass          => $db_pass,
    access_instances => $web_instances,
    mysql_privileges => ['ALL'],
    encoding         => $_encoding,
    collation        => $_collation,
    tls              => $tls,
  }

  if $db_type == 'pgsql' {
    include postgresql::server::contrib

    postgresql::server::extension { "${db_name}-pgcrypto":
      extension => 'pgcrypto',
      database  => $db_name,
    }
  }
}
