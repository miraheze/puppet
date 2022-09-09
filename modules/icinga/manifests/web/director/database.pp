# @summary
#   Setup Director database.
#
# @param [Enum['mysql','pgsql']] db_type
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
class icinga::web::director::database(
  Enum['mysql','pgsql']  $db_type,
  Array[Stdlib::Host]    $web_instances,
  String                 $db_pass,
  String                 $db_name = 'director',
  String                 $db_user = 'director',
) {

  $_db_encoding = $db_type ? {
    'mysql' => 'utf8',
    default => 'UTF8',
  }

  ::icinga::database { "${db_type}-${db_name}":
    db_type          => $db_type,
    db_name          => $db_name,
    db_user          => $db_user,
    db_pass          => $db_pass,
    access_instances => $web_instances,
    mysql_privileges => ['ALL'],
    db_encoding      => $_db_encoding,
  }

  if $db_type == 'pgsql' {
    postgresql::server::extension { "${db_name}-pgcrypto":
      extension    => 'pgcrypto',
      database     => $db_name,
      package_name => 'postgresql-contrib',
    }
  }
}

