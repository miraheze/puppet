# @summary
#   Puppet class to manage IcingaDB.
#
# @example
#   class { 'icingadb':
#     manage_repos  => true,
#     db_type       => 'pgsql',
#     db_password   => 'supersecret',
#     import_schema => true,
#   }
#
# @param ensure
#   Choose wether the service is `running` or `stopped`.
#
# @param enable
#   Choose wether the service has to start at boot.
#
# @param manage_repos
#   Whether to involve the Icinga repositories.
#
# @param manage_packages
#   Whether to manage the IcingaDB packages.
#
# @param redis_host
#   Redis server to connect.
#
# @param redis_port
#   Port on the Redis host to connect.
#
# @param redis_password
#   Passwort to login into redis.
#
# @param redis_use_tls
#   Wether or not to enable tls encryption to connect the database.
#
# @param redis_tls_insecure
#   Disable the server certificate validation. Only valid if `redis_use_tls` is turned on.
#
# @param redis_tls_cert
#   Client certificate in PEM format. Only valid if `redis_use_tls` is turned on.
#
# @param redis_tls_cert_file
#   Location of the client certificate. Only valid if `redis_use_tls` is turned on.
#
# @param redis_tls_key
#   Client private key in PEM format. Only valid if `redis_use_tls` is turned on.
#
# @param redis_tls_key_file
#   Location of the client private key. Only valid if `redis_use_tls` is turned on.
#
# @param redis_tls_cacert
#   CA root certificate in PEM format. Only valid if `redis_use_tls` is turned on.
#
# @param redis_tls_cacert_file
#   Location of the CA root certificate. Only valid if `redis_use_tls` is turned on.
#
# @param db_type
#   Choose wether MySQL or PostgreSQL as backend for historical data.
#
# @param db_host
#   Database server.
#
# @param db_port
#   Port to connect the database.
#
# @param db_name
#   The IcingaDB database.
#
# @param db_username
#   User that is used to connect the database.
#
# @param db_password
#   Passwort to login into database.
#
# @param import_schema
#   Whether or not to import the databse schema or not. Options `mariadb` and `mysql`,
#   both means true. With mariadb its cli options are used for the import,
#   whereas with mysql its different options.
#
# @param db_use_tls
#   Wether or not to enable tls encryption to connect the database.
#
# @param db_tls_insecure
#   Disable the server certificate validation. Only valid if `db_use_tls` is turned on.
#
# @param db_tls_cert
#   Client certificate in PEM format. Only valid if `db_use_tls` is turned on.
#
# @param db_tls_cert_file
#   Location of the client certificate. Only valid if `db_use_tls` is turned on.
#
# @param db_tls_key
#   Client private key in PEM format. Only valid if `db_use_tls` is turned on.
#
# @param db_tls_key_file
#   Location of the client private key. Only valid if `db_use_tls` is turned on.
#
# @param db_tls_cacert
#   CA root certificate in PEM format. Only valid if `db_use_tls` is turned on.
#
# @param db_tls_cacert_file
#   Location of the CA root certificate. Only valid if `db_use_tls` is turned on.
#
# @param db_options
#   List of low-level database options that can be set to influence some
#   Icinga DB internal default behaviours.
#
# @param logging_level
#   Specifies the default logging level. Can be set to fatal, error, warn, info or debug.
#
# @param logging_output
#   Configures the logging output. Can be set to console (stderr) or systemd-journald.
#
# @param logging_interval
#   Interval for periodic logging defined as duration string.
#
# @param logging_options
#   Map of component-logging level pairs to define a different log level than
#   the default value for each component.
#
# @param retention_history_data
#   Number of days to retain full historical data.
#
# @param retention_sla_data
#   Number of days to retain historical data for SLA reporting.
#
# @param retention_options
#   Map of history category to number of days to retain its data in order to
#   enable retention only for specific categories or to override the number
#   that has been configured in `retention_history_data`.
#
class icingadb (
  Icinga::Secret                                 $db_password,
  Enum['running', 'stopped']                     $ensure                 = 'running',
  Boolean                                        $enable                 = true,
  Boolean                                        $manage_repos           = false,
  Boolean                                        $manage_packages        = true,
  Enum['mysql','pgsql']                          $db_type                = 'mysql',
  Stdlib::Host                                   $db_host                = 'localhost',
  Optional[Stdlib::Port]                         $db_port                = undef,
  String[1]                                      $db_name                = 'icingadb',
  String[1]                                      $db_username            = 'icingadb',
  Variant[Boolean, Enum['mariadb', 'mysql']]     $import_schema          = false,
  Optional[Boolean]                              $db_use_tls             = undef,
  Optional[Boolean]                              $db_tls_insecure        = undef,
  Optional[String[1]]                            $db_tls_cert            = undef,
  Optional[Icinga::Secret]                       $db_tls_key             = undef,
  Optional[String[1]]                            $db_tls_cacert          = undef,
  Optional[Stdlib::Absolutepath]                 $db_tls_cert_file       = undef,
  Optional[Stdlib::Absolutepath]                 $db_tls_key_file        = undef,
  Optional[Stdlib::Absolutepath]                 $db_tls_cacert_file     = undef,
  IcingaDB::DBOptions                            $db_options             = {},
  Stdlib::Host                                   $redis_host             = 'localhost',
  Stdlib::Port                                   $redis_port             = 6380,
  Optional[Icinga::Secret]                       $redis_password         = undef,
  Optional[Boolean]                              $redis_use_tls          = undef,
  Optional[Boolean]                              $redis_tls_insecure     = undef,
  Optional[String[1]]                            $redis_tls_cert         = undef,
  Optional[Icinga::Secret]                       $redis_tls_key          = undef,
  Optional[String[1]]                            $redis_tls_cacert       = undef,
  Optional[Stdlib::Absolutepath]                 $redis_tls_cert_file    = undef,
  Optional[Stdlib::Absolutepath]                 $redis_tls_key_file     = undef,
  Optional[Stdlib::Absolutepath]                 $redis_tls_cacert_file  = undef,
  Enum['fatal','error','warn','info','debug']    $logging_level          = 'info',
  Optional[Enum['console','systemd-journald']]   $logging_output         = undef,
  IcingaDB::LoggingOptions                       $logging_options        = {},
  Pattern[/^\d+\.?\d*[d|h|m|s]?$/]               $logging_interval       = '20s',
  Optional[Integer[1]]                           $retention_history_data = undef,
  Optional[Integer[1]]                           $retention_sla_data     = undef,
  IcingaDB::RetentionOptions                     $retention_options      = {},
) {
  require icingadb::globals

  if $manage_repos {
    require icinga::repos
  }

  $conf_dir        = $icingadb::globals::conf_dir
  $db_tls_files    = icinga::cert::files(
    'client_db',
    $conf_dir,
    $db_tls_key_file,
    $db_tls_cert_file,
    $db_tls_cacert_file,
    $db_tls_key,
    $db_tls_cert,
    $db_tls_cacert,
  )
  $redis_tls_files = icinga::cert::files(
    'client_redis',
    $conf_dir,
    $redis_tls_key_file,
    $redis_tls_cert_file,
    $redis_tls_cacert_file,
    $redis_tls_key,
    $redis_tls_cert,
    $redis_tls_cacert,
  )

  #
  # config file content
  #
  $retention = delete_undef_values({
    history-days => $icingadb::retention_history_data,
    sla-days     => $icingadb::retention_sla_data,
    options      => if $icingadb::retention_options.empty { undef } else { $icingadb::retention_options },
  })

  $config    = {
    database => delete_undef_values({
      type     => $db_type,
      host     => $db_host,
      port     => $db_port,
      database => $db_name,
      user     => $db_username,
      password => unwrap($db_password),
      tls      => $db_use_tls,
      cert     => $db_tls_files['cert_file'],
      key      => $db_tls_files['key_file'],
      ca       => $db_tls_files['cacert_file'],
      insecure => $db_tls_insecure,
      options  => if $db_options.empty { undef } else { $db_options },
    }),
    redis    => delete_undef_values({
      host     => $redis_host,
      port     => $redis_port,
      password => unwrap($redis_password),
      tls      => $redis_use_tls,
      cert     => $redis_tls_files['cert_file'],
      key      => $redis_tls_files['key_file'],
      ca       => $redis_tls_files['cacert_file'],
      insecure => $redis_tls_insecure,
    }),
    logging  => delete_undef_values({
      level    => $logging_level,
      output   => $logging_output,
      interval => $logging_interval,
      options  => if $logging_options.empty { undef } else { $logging_options },
    }),
  } + unless $retention.empty {
    { retention => $retention }
  } else {
    {}
  }

  #
  # declarations
  #
  class { 'icingadb::install': }
  -> class { 'icingadb::config':
    notify => Class['icingadb::service'],
  }
  -> class { 'icingadb::install::db': }
  -> class { 'icingadb::service': }

  contain icingadb::install
  contain icingadb::config
  contain icingadb::install::db
  contain icingadb::service
}
