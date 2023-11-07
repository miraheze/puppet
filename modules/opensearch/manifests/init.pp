# Top-level Opensearch class which may manage installation of the
# Opensearch package, package repository, and other
# global options and parameters.
#
# @summary Manages the installation of Opensearch and related options.
#
# @example install Opensearch
#   class { 'opensearch': }
#
# @example removal and decommissioning
#   class { 'opensearch':
#     ensure => 'absent',
#   }
#
# @example install everything but disable service(s) afterwards
#   class { 'opensearch':
#     status => 'disabled',
#   }
#
# @param ensure
#   Controls if the managed resources shall be `present` or `absent`.
#   If set to `absent`, the managed software packages will be uninstalled, and
#   any traces of the packages will be purged as well as possible, possibly
#   including existing configuration files.
#   System modifications (if any) will be reverted as well as possible (e.g.
#   removal of created users, services, changed log settings, and so on).
#   This is a destructive parameter and should be used with care.
#
# @param api_basic_auth_password
#   Defines the default REST basic auth password for API authentication.
#
# @param api_basic_auth_username
#   Defines the default REST basic auth username for API authentication.
#
# @param api_ca_file
#   Path to a CA file which will be used to validate server certs when
#   communicating with the Opensearch API over HTTPS.
#
# @param api_ca_path
#   Path to a directory with CA files which will be used to validate server
#   certs when communicating with the Opensearch API over HTTPS.
#
# @param api_host
#   Default host to use when accessing Opensearch APIs.
#
# @param api_port
#   Default port to use when accessing Opensearch APIs.
#
# @param api_protocol
#   Default protocol to use when accessing Opensearch APIs.
#
# @param api_timeout
#   Default timeout (in seconds) to use when accessing Opensearch APIs.
#
# @param autoupgrade
#   If set to `true`, any managed package will be upgraded on each Puppet run
#   when the package provider is able to find a newer version than the present
#   one. The exact behavior is provider dependent (see
#   {package, "upgradeable"}[http://j.mp/xbxmNP] in the Puppet documentation).
#
# @param ca_certificate
#   Path to the trusted CA certificate to add to this node's Java keystore.
#
# @param certificate
#   Path to the certificate for this node signed by the CA listed in
#   ca_certificate.
#
# @param config
#   Opensearch configuration hash.
#
# @param configdir
#   Directory containing the opensearch configuration.
#   Use this setting if your packages deviate from the norm (`/etc/opensearch`)
#
# @param configdir_recurselimit
#   Dictates how deeply the file copy recursion logic should descend when
#   copying files from the `configdir` to instance `configdir`s.
#
# @param daily_rolling_date_pattern
#   File pattern for the file appender log when file_rolling_type is 'dailyRollingFile'.
#
# @param datadir
#   Allows you to set the data directory of Opensearch.
#
# @param default_logging_level
#   Default logging level for Opensearch.
#
# @param defaults_location
#   Absolute path to directory containing init defaults file.
#
# @param deprecation_logging
#   Whether to enable deprecation logging. If enabled, deprecation logs will be
#   saved to ${cluster.name}_deprecation.log in the Opensearch log folder.
#
# @param deprecation_logging_level
#   Default deprecation logging level for Opensearch.
#
# @param download_tool
#   Command-line invocation with which to retrieve an optional package_url.
#
# @param download_tool_insecure
#   Command-line invocation with which to retrieve an optional package_url when
#   certificate verification should be ignored.
#
# @param download_tool_verify_certificates
#   Whether or not to verify SSL/TLS certificates when retrieving package files
#   using a download tool instead of a package management provider.
#
# @param opensearch_group
#   The group Opensearch should run as. This also sets file group
#   permissions.
#
# @param opensearch_user
#   The user Opensearch should run as. This also sets file ownership.
#
# @param file_rolling_type
#   Configuration for the file appender rotation. It can be 'dailyRollingFile',
#   'rollingFile' or 'file'. The first rotates by name, the second one by size
#   or third don't rotate automatically.
#
# @param homedir
#   Directory where the opensearch installation's files are kept (plugins, etc.)
#
# @param indices
#   Define indices via a hash. This is mainly used with Hiera's auto binding.
#
# @param init_defaults
#   Defaults file content in hash representation.
#
# @param init_defaults_file
#   Defaults file as puppet resource.
#
# @param init_template
#   Service file as a template.
#
# @param jvm_options
#   Array of options to set in jvm_options.
#
# @param keystore_password
#   Password to encrypt this node's Java keystore.
#
# @param keystore_path
#   Custom path to the Java keystore file. This parameter is optional.
#
# @param logdir
#   Directory that will be used for Opensearch logging.
#
# @param logging_config
#   Representation of information to be included in the log4j.properties file.
#
# @param logging_file
#   Instead of a hash, you may supply a `puppet://` file source for the
#   log4j.properties file.
#
# @param logging_level
#   Default logging level for Opensearch.
#
# @param logging_template
#   Use a custom logging template - just supply the relative path, i.e.
#   `$module/opensearch/logging.yml.erb`
#
# @param manage_repo
#   Enable repo management by enabling official Opensearch repositories. (This is temporarily unavailable until https://github.com/opensearch-project/opensearch-build/pull/2526)
#
# @param package_dir
#   Directory where packages are downloaded to.
#
# @param package_dl_timeout
#   For http, https, and ftp downloads, you may set how long the exec resource
#   may take.
#
# @param package_name
#   Name Of the package to install.
#
# @param package_provider
#   Method to install the packages, currently only `package` is supported.
#
# @param package_url
#   URL of the package to download.
#   This can be an http, https, or ftp resource for remote packages, or a
#   `puppet://` resource or `file:/` for local packages
#
# @param pid_dir
#   Directory where the opensearch process should write out its PID.
#
# @param pipelines
#   Define pipelines via a hash. This is mainly used with Hiera's auto binding.
#
# @param plugindir
#   Directory containing opensearch plugins.
#   Use this setting if your packages deviate from the norm (/usr/share/opensearch/plugins)
#
# @param plugins
#   Define plugins via a hash. This is mainly used with Hiera's auto binding.
#
# @param private_key
#   Path to the key associated with this node's certificate.
#
# @param proxy_url
#   For http and https downloads, you may set a proxy server to use. By default,
#   no proxy is used.
#   Format: `proto://[user:pass@]server[:port]/`
#
# @param purge_configdir
#   Purge the config directory of any unmanaged files.
#
# @param purge_package_dir
#   Purge package directory on removal
#
# @param purge_secrets
#   Whether or not keys present in the keystore will be removed if they are not
#   present in the specified secrets hash.
#
# @param repo_stage
#   Use stdlib stage setup for managing the repo instead of relationship
#   ordering.
#
# @param restart_on_change
#   Determines if the application should be automatically restarted
#   whenever the configuration, package, or plugins change. Enabling this
#   setting will cause Opensearch to restart whenever there is cause to
#   re-read configuration files, load new plugins, or start the service using an
#   updated/changed executable. This may be undesireable in highly available
#   environments. If all other restart_* parameters are left unset, the value of
#   `restart_on_change` is used for all other restart_*_change defaults.
#
# @param restart_config_change
#   Determines if the application should be automatically restarted
#   whenever the configuration changes. This includes the Opensearch
#   configuration file, any service files, and defaults files.
#   Disabling automatic restarts on config changes may be desired in an
#   environment where you need to ensure restarts occur in a controlled/rolling
#   manner rather than during a Puppet run.
#
# @param restart_package_change
#   Determines if the application should be automatically restarted
#   whenever the package (or package version) for Opensearch changes.
#   Disabling automatic restarts on package changes may be desired in an
#   environment where you need to ensure restarts occur in a controlled/rolling
#   manner rather than during a Puppet run.
#
# @param restart_plugin_change
#   Determines if the application should be automatically restarted whenever
#   plugins are installed or removed.
#   Disabling automatic restarts on plugin changes may be desired in an
#   environment where you need to ensure restarts occur in a controlled/rolling
#   manner rather than during a Puppet run.
#
# @param roles
#   Define roles via a hash. This is mainly used with Hiera's auto binding.
#
# @param rolling_file_max_backup_index
#   Max number of logs to store whern file_rolling_type is 'rollingFile'
#
# @param rolling_file_max_file_size
#   Max log file size when file_rolling_type is 'rollingFile'
#
# @param scripts
#   Define scripts via a hash. This is mainly used with Hiera's auto binding.
#
# @param secrets
#   Optional default configuration hash of key/value pairs to store in the
#   Opensearch keystore file. If unset, the keystore is left unmanaged.
#
# @param security_logging_content
#   File content for x-pack logging configuration file (will be placed
#   into log4j2.properties file).
#
# @param security_logging_source
#   File source for x-pack logging configuration file (will be placed
#   into log4j2.properties).
#
# @param service_name
#   Opensearch service name
#
# @param service_provider
#   The service resource type provider to use when managing opensearch instances.
#
# @param snapshot_repositories
#   Define snapshot repositories via a hash. This is mainly used with Hiera's auto binding.
#
# @param ssl
#   Whether to manage TLS certificates. Requires the ca_certificate,
#   certificate, private_key and keystore_password parameters to be set.
#
# @param status
#   To define the status of the service. If set to `enabled`, the service will
#   be run and will be started at boot time. If set to `disabled`, the service
#   is stopped and will not be started at boot time. If set to `running`, the
#   service will be run but will not be started at boot time. You may use this
#   to start a service on the first Puppet run instead of the system startup.
#   If set to `unmanaged`, the service will not be started at boot time and Puppet
#   does not care whether the service is running or not. For example, this may
#   be useful if a cluster management software is used to decide when to start
#   the service plus assuring it is running on the desired node.
#
# @param system_key
#   Source for the x-pack system key. Valid values are any that are
#   supported for the file resource `source` parameter.
#
# @param systemd_service_path
#   Path to the directory in which to install systemd service units.
#
# @param templates
#   Define templates via a hash. This is mainly used with Hiera's auto binding.
#
# @param users
#   Define templates via a hash. This is mainly used with Hiera's auto binding.
#
# @param validate_tls
#   Enable TLS/SSL validation on API calls.
#
# @param version
#   To set the specific version you want to install.
#
# @author Richard Pijnenburg <richard.pijnenburg@elasticsearch.com>
# @author Tyler Langlois <tyler.langlois@elastic.co>
# @author Gavin Williams <gavin.williams@elastic.co>
#
class opensearch (
  Enum['absent', 'present']                       $ensure,
  Optional[String]                                $api_basic_auth_password,
  Optional[String]                                $api_basic_auth_username,
  Optional[String]                                $api_ca_file,
  Optional[String]                                $api_ca_path,
  String                                          $api_host,
  Integer[0, 65535]                               $api_port,
  Enum['http', 'https']                           $api_protocol,
  Integer                                         $api_timeout,
  Boolean                                         $autoupgrade,
  Hash                                            $config,
  Stdlib::Absolutepath                            $configdir,
  Integer                                         $configdir_recurselimit,
  String                                          $daily_rolling_date_pattern,
  Opensearch::Multipath                           $datadir,
  Optional[Stdlib::Absolutepath]                  $defaults_location,
  Boolean                                         $deprecation_logging,
  String                                          $deprecation_logging_level,
  Optional[String]                                $download_tool,
  Optional[String]                                $download_tool_insecure,
  Boolean                                         $download_tool_verify_certificates,
  String                                          $opensearch_group,
  String                                          $opensearch_user,
  Enum['dailyRollingFile', 'rollingFile', 'file'] $file_rolling_type,
  Stdlib::Absolutepath                            $homedir,
  Hash                                            $indices,
  Hash                                            $init_defaults,
  Optional[String]                                $init_defaults_file,
  String                                          $init_template,
  Array[String]                                   $jvm_options,
  Stdlib::Absolutepath                            $logdir,
  Hash                                            $logging_config,
  Optional[String]                                $logging_file,
  String                                          $logging_level,
  Optional[String]                                $logging_template,
  Boolean                                         $manage_repo,
  Stdlib::Absolutepath                            $package_dir,
  Integer                                         $package_dl_timeout,
  String                                          $package_name,
  Enum['package']                                 $package_provider,
  Optional[String]                                $package_url,
  Optional[Stdlib::Absolutepath]                  $pid_dir,
  Hash                                            $pipelines,
  Optional[Stdlib::Absolutepath]                  $plugindir,
  Hash                                            $plugins,
  Optional[Stdlib::HTTPUrl]                       $proxy_url,
  Boolean                                         $purge_configdir,
  Boolean                                         $purge_package_dir,
  Boolean                                         $purge_secrets,
  Variant[Boolean, String]                        $repo_stage,
  Boolean                                         $restart_on_change,
  Hash                                            $roles,
  Integer                                         $rolling_file_max_backup_index,
  String                                          $rolling_file_max_file_size,
  Hash                                            $scripts,
  Optional[Hash]                                  $secrets,
  Optional[String]                                $security_logging_content,
  Optional[String]                                $security_logging_source,
  String                                          $service_name,
  Enum['init', 'openbsd', 'openrc', 'systemd']    $service_provider,
  Hash                                            $snapshot_repositories,
  Boolean                                         $ssl,
  Opensearch::Status                              $status,
  Optional[String]                                $system_key,
  Stdlib::Absolutepath                            $systemd_service_path,
  Hash                                            $templates,
  Hash                                            $users,
  Boolean                                         $validate_tls,
  Variant[String, Boolean]                        $version,
  Optional[Stdlib::Absolutepath]                  $ca_certificate            = undef,
  Optional[Stdlib::Absolutepath]                  $certificate               = undef,
  String                                          $default_logging_level     = $logging_level,
  Optional[String]                                $keystore_password         = undef,
  Optional[Stdlib::Absolutepath]                  $keystore_path             = undef,
  Optional[Stdlib::Absolutepath]                  $private_key               = undef,
  Boolean                                         $restart_config_change     = $restart_on_change,
  Boolean                                         $restart_package_change    = $restart_on_change,
  Boolean                                         $restart_plugin_change     = $restart_on_change,
) {
  #### Validate parameters

  if ($package_url != undef and $version != false) {
    fail('Unable to set the version number when using package_url option.')
  }

  if ($version != false) {
    case $facts['os']['family'] {
      'RedHat', 'Linux', 'Suse': {
        if ($version =~ /.+-\d/) {
          $pkg_version = $version
        } else {
          $pkg_version = "${version}-1"
        }
      }
      default: {
        $pkg_version = $version
      }
    }
  }

  # This value serves as an unchanging default for platforms as a default for
  # init scripts to fallback on.
  $_datadir_default = $facts['kernel'] ? {
    'Linux'   => '/var/lib/opensearch',
    'OpenBSD' => '/var/opensearch/data',
    default   => undef,
  }

  # Set the plugin path variable for use later in the module.
  if $plugindir == undef {
    $real_plugindir = "${homedir}/plugins"
  } else {
    $real_plugindir = $plugindir
  }

  # Should we restart Opensearch on config change?
  $_notify_service = $opensearch::restart_config_change ? {
    true  => Service[$opensearch::service_name],
    false => undef,
  }

  #### Manage actions

  contain opensearch::package
  contain opensearch::config
  contain opensearch::service

  create_resources('opensearch::index', $opensearch::indices)
  create_resources('opensearch::pipeline', $opensearch::pipelines)
  create_resources('opensearch::plugin', $opensearch::plugins)
  create_resources('opensearch::role', $opensearch::roles)
  create_resources('opensearch::script', $opensearch::scripts)
  create_resources('opensearch::snapshot_repository', $opensearch::snapshot_repositories)
  create_resources('opensearch::template', $opensearch::templates)
  create_resources('opensearch::user', $opensearch::users)

  if ($manage_repo == true) {
    if ($repo_stage == false) {
      # Use normal relationship ordering
      contain opensearch::repo

      Class['opensearch::repo']
      -> Class['opensearch::package']
    } else {
      # Use staging for ordering
      if !(defined(Stage[$repo_stage])) {
        stage { $repo_stage:  before => Stage['main'] }
      }

      include opensearch::repo
      Class<|title == 'opensearch::repo'|> {
        stage => $repo_stage,
      }
    }
  }

  #### Manage relationships
  #
  # Note that many of these overly verbose declarations work around
  # https://tickets.puppetlabs.com/browse/PUP-1410
  # which means clean arrow order chaining won't work if someone, say,
  # doesn't declare any plugins.
  #
  # forgive me for what you're about to see

  if defined(Class['java']) { Class['java'] -> Class['opensearch::config'] }

  if $ensure == 'present' {
    # Installation, configuration and service
    Class['opensearch::package']
    -> Class['opensearch::config']

    if $restart_config_change {
      Class['opensearch::config'] ~> Class['opensearch::service']
    } else {
      Class['opensearch::config'] -> Class['opensearch::service']
    }

    # Top-level ordering bindings for resources.
    Class['opensearch::config']
    -> Opensearch::Plugin <| ensure == 'present' or ensure == 'installed' |>
    Opensearch::Plugin <| ensure == 'absent' |>
    -> Class['opensearch::config']
    Class['opensearch::config']
    -> Opensearch::User <| ensure == 'present' |>
    # Opensearch::User <| ensure == 'absent' |>
    # -> Class['opensearch::config']
    # Class['opensearch::config']
    # -> Opensearch::Role <| |>
    Class['opensearch::config']
    -> Opensearch::Template <| |>
    Class['opensearch::config']
    -> Opensearch::Pipeline <| |>
    Class['opensearch::config']
    -> Opensearch::Index <| |>
    Class['opensearch::config']
    -> Opensearch::Snapshot_repository <| |>
  } else {
    # Absent; remove configuration before the package.
    Class['opensearch::config']
    -> Class['opensearch::package']

    # Top-level ordering bindings for resources.
    Opensearch::Plugin <| |>
    -> Class['opensearch::config']
    Opensearch::User <| |>
    -> Class['opensearch::config']
    Opensearch::Role <| |>
    -> Class['opensearch::config']
    Opensearch::Template <| |>
    -> Class['opensearch::config']
    Opensearch::Pipeline <| |>
    -> Class['opensearch::config']
    Opensearch::Index <| |>
    -> Class['opensearch::config']
    Opensearch::Snapshot_repository <| |>
    -> Class['opensearch::config']
  }

  # Install plugins before managing users/roles
  Opensearch::Plugin <| ensure == 'present' or ensure == 'installed' |>
  -> Opensearch::User <| |>
  Opensearch::Plugin <| ensure == 'present' or ensure == 'installed' |>
  -> Opensearch::Role <| |>

  # Remove plugins after managing users/roles
  Opensearch::User <| |>
  -> Opensearch::Plugin <| ensure == 'absent' |>
  Opensearch::Role <| |>
  -> Opensearch::Plugin <| ensure == 'absent' |>

  # Ensure roles are defined before managing users that reference roles
  Opensearch::Role <| |>
  -> Opensearch::User <| ensure == 'present' |>
  # Ensure users are removed before referenced roles are managed
  Opensearch::User <| ensure == 'absent' |>
  -> Opensearch::Role <| |>

  # Ensure users and roles are managed before calling out to REST resources
  Opensearch::Role <| |>
  -> Opensearch::Template <| |>
  Opensearch::User <| |>
  -> Opensearch::Template <| |>
  Opensearch::Role <| |>
  -> Opensearch::Pipeline <| |>
  Opensearch::User <| |>
  -> Opensearch::Pipeline <| |>
  Opensearch::Role <| |>
  -> Opensearch::Index <| |>
  Opensearch::User <| |>
  -> Opensearch::Index <| |>
  Opensearch::Role <| |>
  -> Opensearch::Snapshot_repository <| |>
  Opensearch::User <| |>
  -> Opensearch::Snapshot_repository <| |>

  # Ensure that any command-line based user changes are performed before the
  # file is modified
  Opensearch_user <| |>
  -> Opensearch_user_file <| |>
}
