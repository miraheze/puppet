# @summary A short summary of the purpose of this class
#   Configures IcingaDB
#
# @api private
#
class icingadb::config {
  assert_private()

  $stdlib_version  = $icingadb::globals::stdlib_version
  $conf_dir        = $icingadb::globals::conf_dir
  $user            = $icingadb::globals::user
  $group           = $icingadb::globals::group
  $redis_tls_files = $icingadb::redis_tls_files
  $db_tls_files    = $icingadb::db_tls_files
  $config_content  = if versioncmp($stdlib_version, '9.0.0') < 0 {
    to_yaml($icingadb::config)
  } else {
    stdlib::to_yaml($icingadb::config)
  }

  icinga::cert { 'icingadb tls files for the database client connect':
    owner => $user,
    group => $group,
    args  => $db_tls_files,
  }

  icinga::cert { 'icingadb tls files for the redis client connect':
    owner => $user,
    group => $group,
    args  => $redis_tls_files,
  }

  file { "${conf_dir}/config.yml":
    ensure    => file,
    show_diff => false,
    owner     => $user,
    group     => $group,
    mode      => '0640',
    content   => $config_content,
  }

  -> File <| ensure != 'directory' and tag == 'icingadb::config::file' |>
}
