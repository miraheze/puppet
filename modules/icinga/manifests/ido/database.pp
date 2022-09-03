# @summary
#   Configure IDO backend database.
#
# @param [Enum['mysql','pgsql']] db_type
#   What kind of database type to use.
#
# @param [Array[Stdlib::Host]] ido_instances
#   List of Hosts to allow write access to the database. Usually an Icinga Server with IDO feature.
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
class icinga::ido::database(
  Enum['mysql','pgsql']  $db_type,
  Array[Stdlib::Host]    $ido_instances,
  String                 $db_pass,
  String                 $db_name = 'icinga2',
  String                 $db_user = 'icinga2',
) {

  ::icinga::database { "${db_type}-${db_name}":
    db_type          => $db_type,
    db_name          => $db_name,
    db_user          => $db_user,
    db_pass          => $db_pass,
    access_instances => $ido_instances,
    mysql_privileges => ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE VIEW', 'CREATE', 'ALTER', 'INDEX', 'EXECUTE'],
  }

}
