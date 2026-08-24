# @summary
#   Imports IcingaDB database schema
#
# @api private
#
class icingadb::install::db {
  assert_private()

  $import_schema = $icingadb::import_schema

  if $import_schema {
    $type = if $icingadb::db_type == 'pgsql' {
      'pgsql'
    } else {
      if $import_schema =~ Boolean {
        'mariadb'
      } else {
        $import_schema
      }
    }

    $db_host     = $icingadb::db_host
    $db_port     = $icingadb::db_port
    $db_name     = $icingadb::db_name
    $db_username = $icingadb::db_username
    $db_password = $icingadb::db_password

    $db_cli_options = icinga::db::connect({
      type     => $type,
      host     => $db_host,
      port     => $db_port,
      database => $db_name,
      username => $db_username,
      password => $db_password,
    }, $icingadb::db_tls_files + { noverify => $icingadb::db_tls_insecure }, $icingadb::db_use_tls)

    if $type == 'pgsql' {
      $db_schema = $icingadb::globals::pgsql_db_schema
      exec { 'icingadb-pgsql-import-schema':
        user        => 'root',
        path        => $facts['path'],
        environment => [sprintf('PGPASSWORD=%s', unwrap($db_password))],
        command     => "psql '${db_cli_options}' -w -f '${db_schema}'",
        unless      => "psql '${db_cli_options}' -w -c 'select version from icingadb_schema'",
      }
    } else {
      $db_schema = $icingadb::globals::mysql_db_schema
      exec { 'icingadb-mysql-import-schema':
        user    => 'root',
        path    => $facts['path'],
        command => "mysql ${db_cli_options} < \"${db_schema}\"",
        unless  => "mysql ${db_cli_options} -Ns -e 'select version from icingadb_schema'",
      }
    }
  }
}
