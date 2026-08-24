# @summary 
#   Configures IcingaDB Redis server
#
# @api private
#   
class icingadb::redis::config {
  assert_private()

  $conf_dir         = $icingadb::redis::globals::conf_dir
  $user             = $icingadb::redis::globals::user
  $group            = $icingadb::redis::globals::group
  $port             = $icingadb::redis::port
  $use_tls          = $icingadb::redis::use_tls
  $tls_port         = $icingadb::redis::tls_port
  $tls_auth_clients = $icingadb::redis::tls_auth_clients

  if $use_tls {
    $tls_files = icinga::cert::files(
      'server',
      $conf_dir,
      $icingadb::redis::tls_key_file,
      $icingadb::redis::tls_cert_file,
      $icingadb::redis::tls_cacert_file,
      $icingadb::redis::tls_key,
      $icingadb::redis::tls_cert,
      $icingadb::redis::tls_cacert,
    )

    icinga::cert { 'icingadb-redis tls files for the database client connect':
      owner => $user,
      group => $group,
      args  => $tls_files,
    }

    $tls_settings = delete_undef_values({
      port             => if $port != $tls_port { undef } else { 0 },
      tls_port         => $tls_port,
      tls_cert_file    => $tls_files['cert_file'],
      tls_key_file     => $tls_files['key_file'],
      tls_ca_cert_file => $tls_files['cacert_file'],
      tls_auth_clients => $tls_auth_clients,
    })
  } else {
    $tls_settings = {}
  }

  redis::instance { 'icingadb-redis':
    * => $icingadb::redis::config + {
      bind                => any2array($icingadb::redis::bind),
      config_file         => "${conf_dir}/icingadb-redis.conf",
      config_file_orig    => "${conf_dir}/icingadb-redis.conf",
      config_owner        => $user,
      config_group        => $group,
      port                => $port,
      daemonize           => true,
      service_user        => $user,
      service_group       => $group,
      workdir             => $icingadb::redis::globals::work_dir,
      manage_service_file => false,
      service_name        => $icingadb::redis::globals::service_name,
      pid_file            => "${icingadb::redis::globals::run_dir}/icingadb-redis-server.pid",
      log_file            => "${icingadb::redis::globals::log_dir}/icingadb-redis-server.log",
      requirepass         => unwrap($icingadb::redis::requirepass),
    } + $tls_settings,
  }

  -> File <| ensure != 'directory' and tag == 'icingadb::redis::config::file' |>
}
