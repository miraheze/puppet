# @summary
#   Private define resource for database backends.
#
# @api private
#
define icinga::database (
  Enum['mysql','pgsql']      $db_type,
  Array[Stdlib::Host]        $access_instances,
  Icinga::Secret             $db_pass,
  String[1]                  $db_name,
  String[1]                  $db_user,
  Array[String[1]]           $mysql_privileges,
  Variant[Boolean,
  Enum['password','cert']]   $tls       = false,
  Optional[String[1]]        $encoding  = undef,
  Optional[String[1]]        $collation = undef,
) {
  assert_private()

  if $db_type == 'pgsql' {
    include postgresql::server

    $_auth_method = if $tls =~ String and $tls == 'cert' {
      'cert'
    } else {
      unless $postgresql::server::password_encryption {
        'md5'
      } else {
        $postgresql::server::password_encryption
      }
    }

    if versioncmp($facts['puppetversion'], '6.0.0') < 0  or ($facts['os']['family'] == 'redhat' and Integer($facts['os']['release']['major']) < 8) {
      $_pass = unwrap($db_pass)
    } else {
      $_pass = postgresql::postgresql_password($db_user, $db_pass, false, $postgresql::server::password_encryption)
    }

    if $tls {
      $host_type = 'hostssl'
    } else {
      $host_type = 'host'
    }

    postgresql::server::db { $db_name:
      user     => $db_user,
      password => $_pass,
      encoding => $encoding,
      locale   => $collation,
      owner    => $db_user,
    }

    $access_instances.each |$host| {
      if $host =~ Stdlib::IP::Address::V4 {
        $_net = '/32'
      } elsif $host =~ Stdlib::IP::Address::V6 {
        $_net = '/128'
      } else {
        $_net = ''
      }

      postgresql::server::pg_hba_rule { "${db_user}@${host}":
        type        => $host_type,
        database    => $db_name,
        user        => $db_user,
        auth_method => $_auth_method,
        address     => "${host}${_net}",
      }
    }
  } else {
    include mysql::server

    $_tls_options = if $tls {
      if $tls =~ String and $tls == 'cert' {
        'X509'
      } else {
        'SSL'
      }
    } else {
      'NONE'
    }

    mysql::db { $db_name:
      host        => $access_instances[0],
      user        => $db_user,
      tls_options => any2array($_tls_options),
      password    => $db_pass,
      grant       => $mysql_privileges,
      charset     => $encoding,
      collate     => $collation,
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
