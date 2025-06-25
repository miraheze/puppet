# @summary
#   Configure IDO backend database.
#
# @param db_type
#   What kind of database type to use.
#
# @param ido_instances
#   List of Hosts to allow write access to the database.
#   Usually an Icinga Server with enabled IDO feature.
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
class icinga::ido::database (
  Enum['mysql','pgsql']      $db_type,
  Array[Stdlib::Host]        $ido_instances,
  Icinga::Secret             $db_pass,
  String[1]                  $db_name  = 'icinga2',
  String[1]                  $db_user  = 'icinga2',
  Variant[Boolean,
  Enum['password','cert']]   $tls      = false,
) {
  icinga::database { "${db_type}-${db_name}":
    db_type          => $db_type,
    db_name          => $db_name,
    db_user          => $db_user,
    db_pass          => $db_pass,
    access_instances => $ido_instances,
    mysql_privileges => ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE VIEW', 'CREATE', 'ALTER', 'INDEX', 'CREATE ROUTINE', 'ALTER ROUTINE', 'EXECUTE'],
    tls              => $tls,
  }
}
