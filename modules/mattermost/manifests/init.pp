# See README.md.
class mattermost (
  Boolean $install_from_pkg           = $mattermost::params::install_from_pkg,
  String $pkg                         = $mattermost::params::pkg,
  String $base_url                    = $mattermost::params::base_url,
  Enum['team', 'enterprise'] $edition = $mattermost::params::edition,
  String $version                     = $mattermost::params::version,
  String $filename                    = $mattermost::params::filename,
  String $full_url                    = $mattermost::params::full_url,
  Stdlib::Absolutepath $dir           = $mattermost::params::dir,
  Stdlib::Absolutepath $symlink       = $mattermost::params::symlink,
  Boolean $create_user                = $mattermost::params::create_user,
  Boolean $create_group               = $mattermost::params::create_group,
  String $user                        = $mattermost::params::user,
  String $group                       = $mattermost::params::group,
  Integer $uid                        = $mattermost::params::uid,
  Integer $gid                        = $mattermost::params::gid,
  String $conf                        = $mattermost::params::conf,
  Hash $override_options              = $mattermost::params::override_options,
  String $env_conf                    = $mattermost::params::env_conf,
  Hash $override_env_options          = $mattermost::params::override_env_options,
  Boolean $manage_data_dir            = $mattermost::params::manage_data_dir,
  Boolean $manage_log_dir             = $mattermost::params::manage_log_dir,
  String $depend_service              = $mattermost::params::depend_service,
  Boolean $install_service            = $mattermost::params::install_service,
  Boolean $manage_service             = $mattermost::params::manage_service,
  String $service_name                = $mattermost::params::service_name,
  String $service_template            = $mattermost::params::service_template,
  String $service_path                = $mattermost::params::service_path,
  String $service_provider            = $mattermost::params::service_provider,
  Boolean $purge_conf                 = $mattermost::params::purge_conf,
  Boolean $purge_env_conf             = $mattermost::params::purge_env_conf,
) inherits mattermost::params {
  if $override_env_options['MM_FILESETTINGS_DIRECTORY'] {
    $data_dir = assert_type(Stdlib::Absolutepath, $override_env_options['MM_FILESETTINGS_DIRECTORY'])
  }
  elsif $override_options['FileSettings'] {
    if $override_options['FileSettings']['Directory'] {
      $data_dir = assert_type(Stdlib::Absolutepath, $override_options['FileSettings']['Directory'])
    }
    else {
      $data_dir = undef
    }
  }
  else {
    $data_dir = undef
  }
  if $override_env_options['MM_LOGSETTINGS_FILELOCATION'] {
    $log_dir = assert_type(Stdlib::Absolutepath, $override_env_options['MM_LOGSETTINGS_FILELOCATION'])
  }
  elsif $override_options['LogSettings'] {
    if $override_options['LogSettings']['FileLocation'] {
      $log_dir = assert_type(Stdlib::Absolutepath, $override_options['LogSettings']['FileLocation'])
    }
    else {
      $log_dir = undef
    }
  }
  else {
    $log_dir = undef
  }
  if versioncmp($version, '5.0.0') >= 0 {
    $executable = 'mattermost'
  }
  else {
    $executable = 'platform'
  }
  anchor { 'mattermost::begin': }
  -> class { 'mattermost::install': }
  -> class { 'mattermost::config': }
  ~> class { 'mattermost::service': }
  -> anchor { 'mattermost::end': }
}
