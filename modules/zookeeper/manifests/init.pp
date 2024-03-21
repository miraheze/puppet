# @summary Manages ZooKeeper installation
#
# @param ensure
#   Package ensure, `present`, `absent` or specific version, default: present
# @param ensure_account
#   Wheter user account and group should be created, default: present
# @param ensure_cron
#
# @param group
#   Name of the group, default: zookeeper
# @param system_group
#   Whether create system group, default: false
# @param packages
#   Array of packages to be installed, default: OS dependent
# @param shell
#
# @param user
#   User account name
# @param system_user
#   Whether create a system user, default:false
# @param archive_checksum
# @param archive_dl_site
# @param archive_dl_timeout
# @param archive_dl_url
# @param archive_install_dir
# @param archive_symlink
# @param archive_symlink_name
# @param archive_version
# @param repo_user
# @param repo_password
# @param proxy_server
# @param proxy_type
# @param cdhver
# @param install_java
# @param install_method
# @param java_bin
# @param java_opts
# @param java_package
# @param repo
# @param manage_service
# @param manage_service_file
# @param pid_dir
# @param pid_file
# @param restart_on_change
# @param service_ensure
# @param service_name
# @param service_provider
# @param systemd_unit_want
# @param systemd_unit_after
# @param systemd_path
# @param zk_dir

# @param cfg_dir
# @param cleanup_sh
# @param client_ip
# @param client_port
# @param secure_client_port
# @param secure_port_only
# @param ssl
# @param ssl_clientauth
# @param keystore_location
# @param keystore_type
# @param keystore_password
# @param truststore_location
# @param truststore_type
# @param truststore_password
# @param ssl_hostname_verification
# @param ssl_ciphersuites
# @param ssl_protocol
# @param keystore_quorum_location
# @param keystore_quorum_type
# @param keystore_quorum_password
# @param truststore_quorum_location
# @param truststore_quorum_type
# @param truststore_quorum_password
# @param ssl_quorum_hostname_verification
# @param ssl_quorum_ciphersuites
# @param ssl_quorum_protocol
# @param ssl_quorum
# @param port_unification
# @param datastore
# @param datalogstore
#   Defining `dataLogDir` allows ZooKeeper transaction logs to be stored in a different location,
#   might improve I/O performance (e.g. if path is mounted on dedicated disk)
# @param election_port
# @param export_tag
# @param id
#   Cluster-unique zookeeper's instance ID (integer 1-255)
# @param init_limit
# @param initialize_datastore
# @param initialize_datastore_bin
# @param leader
# @param leader_port
# @param log_dir
# @param manual_clean
# @param max_session_timeout
# @param min_session_timeout
# @param observers
# @param purge_interval
#   Automatically delete ZooKeeper logs (available since ZooKeeper 3.4.0)
# @param servers
# @param pre_alloc_size
# @param snap_count
# @param snap_retain_count
# @param sync_limit
# @param tick_time
# @param global_outstanding_limit
#   Clients can submit requests faster than ZooKeeper can process them,
#   especially if there are a lot of clients. To prevent ZooKeeper from running out of memory due to
#   queued requests, ZooKeeper will throttle clients so that there is no more than globalOutstandingLimit
#   outstanding requests in the system
# @param use_sasl_auth
# @param zoo_dir
# @param zoo_main
# @param quorum_listen_on_all_ips
# @param audit_enable

# @param environment_file
# @param log4j_prop
# @param maxfilesize
# @param maxbackupindex
# @param max_allowed_connections
# @param peer_type
# @param rollingfile_threshold
# @param tracefile_threshold
# @param console_threshold
# @param extra_appenders
# @param audit_threshold
# @param audit_maxfilesize
# @param audit_maxbackupindex
# @param sasl_users
# @param keytab_path
# @param principal
# @param realm
# @param sasl_krb5
# @param store_key
# @param use_keytab
# @param use_ticket_cache
# @param remove_host_principal
# @param remove_realm_principal
# @param whitelist_4lw
#   Fine grained control over the set of commands ZooKeeper can execute
#
#                   whitelist_4lw = ['stat','ruok']
# @param metrics_provider_classname
# @param metrics_provider_http_port
# @param metrics_provider_export_jvm_info
#
class zookeeper (
  # meta options
  String                                     $ensure                           = $zookeeper::params::ensure,
  Variant[Boolean,String]                    $ensure_account                   = $zookeeper::params::ensure_account,
  Boolean                                    $ensure_cron                      = $zookeeper::params::ensure_cron,
  String                                     $group                            = $zookeeper::params::group,
  Boolean                                    $system_group                     = $zookeeper::params::system_group,
  Array[String]                              $packages                         = $zookeeper::params::packages,
  String                                     $shell                            = $zookeeper::params::shell,
  String                                     $user                             = $zookeeper::params::user,
  Boolean                                    $system_user                      = $zookeeper::params::system_user,
  # installation options
  Hash                                       $archive_checksum                 = $zookeeper::params::archive_checksum,
  Optional[String]                           $archive_dl_site                  = $zookeeper::params::archive_dl_site,
  Integer                                    $archive_dl_timeout               = $zookeeper::params::archive_dl_timeout,
  Optional[String]                           $archive_dl_url                   = $zookeeper::params::archive_dl_url,
  String                                     $archive_install_dir              = $zookeeper::params::archive_install_dir,
  Boolean                                    $archive_symlink                  = $zookeeper::params::archive_symlink,
  String                                     $archive_symlink_name             = $zookeeper::params::archive_symlink_name,
  String                                     $archive_version                  = $zookeeper::params::archive_version,
  Optional[String]                           $repo_user                        = $zookeeper::params::repo_user,
  Optional[String]                           $repo_password                    = $zookeeper::params::repo_password,
  Optional[String]                           $proxy_server                     = $zookeeper::params::proxy_server,
  Optional[String]                           $proxy_type                       = $zookeeper::params::proxy_type,
  Optional[String]                           $cdhver                           = $zookeeper::params::cdhver,
  Boolean                                    $install_java                     = $zookeeper::params::install_java,
  String                                     $install_method                   = $zookeeper::params::install_method,
  String                                     $java_bin                         = $zookeeper::params::java_bin,
  String                                     $java_opts                        = $zookeeper::params::java_opts,
  Optional[String]                           $java_package                     = $zookeeper::params::java_package,
  Optional[Hash]                             $repo                             = $zookeeper::params::repo,
  # service options
  Boolean                                    $manage_service                   = $zookeeper::params::manage_service,
  Boolean                                    $manage_service_file              = $zookeeper::params::manage_service_file,
  String                                     $pid_dir                          = $zookeeper::params::pid_dir,
  Optional[String]                           $pid_file                         = $zookeeper::params::pid_file,
  Boolean                                    $restart_on_change                = $zookeeper::params::restart_on_change,
  String                                     $service_ensure                   = $zookeeper::params::service_ensure,
  String                                     $service_name                     = $zookeeper::params::service_name,
  Optional[String]                           $service_provider                 = $zookeeper::params::service_provider,
  Optional[String]                           $systemd_unit_want                = $zookeeper::params::systemd_unit_want,
  String                                     $systemd_unit_after               = $zookeeper::params::systemd_unit_after,
  String                                     $systemd_path                     = $zookeeper::params::systemd_path,
  String                                     $zk_dir                           = $zookeeper::params::zk_dir,
  # zookeeper config
  String                                     $cfg_dir                          = $zookeeper::params::cfg_dir,
  String                                     $cleanup_sh                       = $zookeeper::params::cleanup_sh,
  Optional[String]                           $client_ip                        = $zookeeper::params::client_ip,
  Integer                                    $client_port                      = $zookeeper::params::client_port,
  Optional[Integer]                          $secure_client_port               = $zookeeper::params::secure_client_port,
  Optional[Boolean]                          $secure_port_only                 = $zookeeper::params::secure_port_only,
  Optional[Boolean]                          $ssl                              = $zookeeper::params::ssl,
  Optional[String]                           $ssl_clientauth                   = $zookeeper::params::ssl_clientauth,
  Optional[String]                           $keystore_location                = $zookeeper::params::keystore_location,
  Optional[String]                           $keystore_type                    = $zookeeper::params::keystore_type,
  Optional[String]                           $keystore_password                = $zookeeper::params::keystore_password,
  Optional[String]                           $truststore_location              = $zookeeper::params::truststore_location,
  Optional[String]                           $truststore_type                  = $zookeeper::params::truststore_type,
  Optional[String]                           $truststore_password              = $zookeeper::params::truststore_password,
  Optional[Boolean]                          $ssl_hostname_verification        = $zookeeper::params::ssl_hostname_verification,
  Optional[String]                           $ssl_ciphersuites                 = $zookeeper::params::ssl_ciphersuites,
  Optional[String]                           $ssl_protocol                     = $zookeeper::params::ssl_protocol,
  Optional[String]                           $keystore_quorum_location         = $zookeeper::params::keystore_quorum_location,
  Optional[String]                           $keystore_quorum_type             = $zookeeper::params::keystore_quorum_type,
  Optional[String]                           $keystore_quorum_password         = $zookeeper::params::keystore_quorum_password,
  Optional[String]                           $truststore_quorum_location       = $zookeeper::params::truststore_quorum_location,
  Optional[String]                           $truststore_quorum_type           = $zookeeper::params::truststore_quorum_type,
  Optional[String]                           $truststore_quorum_password       = $zookeeper::params::truststore_quorum_password,
  Optional[Boolean]                          $ssl_quorum_hostname_verification = $zookeeper::params::ssl_quorum_hostname_verification,
  Optional[String]                           $ssl_quorum_ciphersuites          = $zookeeper::params::ssl_quorum_ciphersuites,
  Optional[String]                           $ssl_quorum_protocol              = $zookeeper::params::ssl_quorum_protocol,
  Optional[Boolean]                          $ssl_quorum                       = $zookeeper::params::ssl_quorum,
  Optional[Boolean]                          $port_unification                 = $zookeeper::params::port_unification,
  String                                     $datastore                        = $zookeeper::params::datastore,
  Optional[String]                           $datalogstore                     = $zookeeper::params::datalogstore,
  Integer                                    $election_port                    = $zookeeper::params::election_port,
  String                                     $export_tag                       = $zookeeper::params::export_tag,
  String                                     $id                               = $zookeeper::params::id,
  Integer                                    $init_limit                       = $zookeeper::params::init_limit,
  Boolean                                    $initialize_datastore             = $zookeeper::params::initialize_datastore,
  String                                     $initialize_datastore_bin         = $zookeeper::params::initialize_datastore_bin,
  Boolean                                    $leader                           = $zookeeper::params::leader,
  Integer                                    $leader_port                      = $zookeeper::params::leader_port,
  String                                     $log_dir                          = $zookeeper::params::log_dir,
  Boolean                                    $manual_clean                     = $zookeeper::params::manual_clean,
  Optional[Integer]                          $max_session_timeout              = $zookeeper::params::max_session_timeout,
  Optional[Integer]                          $min_session_timeout              = $zookeeper::params::min_session_timeout,
  Array[String]                              $observers                        = $zookeeper::params::observers,
  Integer                                    $purge_interval                   = $zookeeper::params::purge_interval,
  Variant[Array[String],Hash[String,String]] $servers                          = $zookeeper::params::servers,
  Integer                                    $pre_alloc_size                   = $zookeeper::params::pre_alloc_size,
  Integer                                    $snap_count                       = $zookeeper::params::snap_count,
  Integer                                    $snap_retain_count                = $zookeeper::params::snap_retain_count,
  Integer                                    $sync_limit                       = $zookeeper::params::sync_limit,
  Integer                                    $tick_time                        = $zookeeper::params::tick_time,
  Integer                                    $global_outstanding_limit         = $zookeeper::params::global_outstanding_limit,
  Boolean                                    $use_sasl_auth                    = $zookeeper::params::use_sasl_auth,
  String                                     $zoo_dir                          = $zookeeper::params::zoo_dir,
  String                                     $zoo_main                         = $zookeeper::params::zoo_main,
  Boolean                                    $quorum_listen_on_all_ips         = $zookeeper::params::quorum_listen_on_all_ips,
  Boolean                                    $audit_enable                     = $zookeeper::params::audit_enable,
  # log4j properties
  String                                     $environment_file                 = $zookeeper::params::environment_file,
  String                                     $log4j_prop                       = $zookeeper::params::log4j_prop,
  String                                     $maxfilesize                      = $zookeeper::params::maxfilesize,
  Integer                                    $maxbackupindex                   = $zookeeper::params::maxbackupindex,
  Optional[Integer]                          $max_allowed_connections          = $zookeeper::params::max_allowed_connections,
  String                                     $peer_type                        = $zookeeper::params::peer_type,
  String                                     $rollingfile_threshold            = $zookeeper::params::rollingfile_threshold,
  String                                     $tracefile_threshold              = $zookeeper::params::tracefile_threshold,
  String                                     $console_threshold                = $zookeeper::params::console_threshold,
  Hash[String,Hash[String,String]]           $extra_appenders                  = $zookeeper::params::extra_appenders,
  String                                     $audit_threshold                  = $zookeeper::params::audit_threshold,
  String                                     $audit_maxfilesize                = $zookeeper::params::audit_maxfilesize,
  String                                     $audit_maxbackupindex             = $zookeeper::params::audit_maxbackupindex,
  # sasl options
  Hash[String, String]                       $sasl_users                       = $zookeeper::params::sasl_users,
  String                                     $keytab_path                      = $zookeeper::params::keytab_path,
  String                                     $principal                        = $zookeeper::params::principal,
  String                                     $realm                            = $zookeeper::params::realm,
  Boolean                                    $sasl_krb5                        = $zookeeper::params::sasl_krb5,
  Boolean                                    $store_key                        = $zookeeper::params::store_key,
  Boolean                                    $use_keytab                       = $zookeeper::params::use_keytab,
  Boolean                                    $use_ticket_cache                 = $zookeeper::params::use_ticket_cache,
  Boolean                                    $remove_host_principal            = $zookeeper::params::remove_host_principal,
  Boolean                                    $remove_realm_principal           = $zookeeper::params::remove_realm_principal,
  # four letter words whitelist
  Array[String]                              $whitelist_4lw                    = $zookeeper::params::whitelist_4lw,
  # Metrics Providers
  Optional[String]                           $metrics_provider_classname       = $zookeeper::params::metrics_provider_classname,
  Integer                                    $metrics_provider_http_port       = $zookeeper::params::metrics_provider_http_port,
  Boolean                                    $metrics_provider_export_jvm_info = $zookeeper::params::metrics_provider_export_jvm_info,
) inherits zookeeper::params {
  if $pid_file {
    $pid_path = $pid_file
  } else {
    $pid_path = "${pid_dir}/zookeeper.pid"
  }

  if $zookeeper::ensure_account {
    group { $group:
      ensure => $ensure_account,
      system => $system_group,
    }

    user { $user:
      ensure  => $ensure_account,
      home    => $datastore,
      comment => 'Zookeeper',
      gid     => $group,
      shell   => $shell,
      system  => $system_user,
      require => Group[$group],
    }
  }

  contain zookeeper::install
  contain zookeeper::config
  Class['zookeeper::install']
  -> Class['zookeeper::config']

  if ($use_sasl_auth) {
    contain zookeeper::sasl
    Class['zookeeper::config']
    -> Class['zookeeper::sasl']
    -> Class['zookeeper::service']
  }

  if ($manage_service) and ($service_provider != 'exhibitor') {
    contain zookeeper::service
    Class['zookeeper::config']
    -> Class['zookeeper::service']
  }
}
