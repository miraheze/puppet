# @summary
#   Setup VSphereDB database.
#
# @param [Enum['mysql']] db_type
#   What kind of database type to use.
#
# @param [Array[Stdlib::Host]] web_instances
#   List of Hosts to allow write access to the database. Usually an Icinga Web 2 instance.
#
# @param [String] db_pass
#   Password to connect the database.
#
# @param [String] db_name
#   Name of the database.
#
# @param [String] db_user
#   Database user name.
#
class icinga::web::vspheredb::database(
  Enum['mysql']          $db_type,
  Array[Stdlib::Host]    $web_instances,
  String                 $db_pass,
  String                 $db_name = 'vspheredb',
  String                 $db_user = 'vspheredb',
) {

  if $db_type != 'mysql' {
    $_db_encoding  = 'UTF8'
    $_db_collation = undef
  } else {
    $_db_encoding  = 'utf8mb4'
    $_db_collation = 'utf8mb4_bin'
  }

  ::icinga::database { "${db_type}-${db_name}":
    db_type          => $db_type,
    db_name          => $db_name,
    db_user          => $db_user,
    db_pass          => $db_pass,
    access_instances => $web_instances,
    mysql_privileges => ['ALL'],
    db_encoding      => $_db_encoding,
    db_collation     => $_db_collation,
  }
}
