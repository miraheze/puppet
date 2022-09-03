# @summary
#   Private define resource for database backends.
#
# @api private
#
define icinga::database(
  Enum['mysql','pgsql']  $db_type,
  Array[Stdlib::Host]    $access_instances,
  String                 $db_pass,
  String                 $db_name,
  String                 $db_user,
  Array[String]          $mysql_privileges,
  Optional[String]       $db_encoding  = undef,
  Optional[String]       $db_collation = undef,
) {

  if $db_type == 'pgsql' {
    include ::postgresql::server

    if versioncmp($::facts['puppetversion'], '6.0.0') < 0 {
      $_password = $db_pass
    } else {
      $_password = postgresql::postgresql_password($db_user, $db_pass)
    }

    postgresql::server::db { $db_name:
      user     => $db_user,
      password => $_password,
      encoding => $db_encoding,
      locale   => $db_collation,
    }

    $access_instances.each |$host| {
      if $host =~ Stdlib::IP::Address::V4 {
        $_net = '/32'
      } elsif $host =~ Stdlib::IP::Address::V6 {
        $_net = '/128'
      } else {
        $_net = ''
      }

      ::postgresql::server::pg_hba_rule { "${db_user}@${host}":
        type        => 'host',
        database    => $db_name,
        user        => $db_user,
        auth_method => 'md5',
        address     => "${host}${_net}",
      }
    }
  } else {
    include ::mysql::server

    $_db_encoding = $db_encoding

    mysql::db { $db_name:
      host     => $access_instances[0],
      user     => $db_user,
      password => $db_pass,
      grant    => $mysql_privileges,
      charset  => $_db_encoding,
      collate  => $db_collation,
    }

    delete_at($access_instances,0).each |$host| {
      mysql_user { "${db_user}@${host}":
        password_hash => mysql::password($db_pass),
      }
      mysql_grant { "${db_user}@${host}/${db_name}.*":
        user       => "${db_user}@${host}",
        table      => "${db_name}.*",
        privileges => $mysql_privileges,
      }
    }
  }
}
