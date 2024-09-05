# See README.md.
class mattermost (
  $install_from_pkg     = $mattermost::params::install_from_pkg,
  $pkg                  = $mattermost::params::pkg,
  $base_url             = $mattermost::params::base_url,
  $edition              = $mattermost::params::edition,
  $version              = $mattermost::params::version,
  $filename             = $mattermost::params::filename,
  $full_url             = $mattermost::params::full_url,
  $dir                  = $mattermost::params::dir,
  $symlink              = $mattermost::params::symlink,
  $create_user          = $mattermost::params::create_user,
  $create_group         = $mattermost::params::create_group,
  $user                 = $mattermost::params::user,
  $group                = $mattermost::params::group,
  $uid                  = $mattermost::params::uid,
  $gid                  = $mattermost::params::gid,
  $conf                 = $mattermost::params::conf,
  $override_options     = $mattermost::params::override_options,
  $env_conf             = $mattermost::params::env_conf,
  $override_env_options = $mattermost::params::override_env_options,
  $manage_data_dir      = $mattermost::params::manage_data_dir,
  $manage_log_dir       = $mattermost::params::manage_log_dir,
  $depend_service       = $mattermost::params::depend_service,
  $install_service      = $mattermost::params::install_service,
  $manage_service       = $mattermost::params::manage_service,
  $service_name         = $mattermost::params::service_name,
  $service_template     = $mattermost::params::service_template,
  $service_path         = $mattermost::params::service_path,
  $service_provider     = $mattermost::params::service_provider,
  $purge_conf           = $mattermost::params::purge_conf,
  $purge_env_conf       = $mattermost::params::purge_env_conf,
) inherits mattermost::params {
  if $override_env_options['MM_FILESETTINGS_DIRECTORY'] {
    $data_dir = $override_env_options['MM_FILESETTINGS_DIRECTORY']
  }
  elsif $override_options['FileSettings'] {
    if $override_options['FileSettings']['Directory'] {
      $data_dir = $override_options['FileSettings']['Directory']
    }
    else {
      $data_dir = undef
    }
  }
  else {
    $data_dir = undef
  }
  if $override_env_options['MM_LOGSETTINGS_FILELOCATION'] {
    $log_dir = $override_env_options['MM_LOGSETTINGS_FILELOCATION']
  }
  elsif $override_options['LogSettings'] {
    if $override_options['LogSettings']['FileLocation'] {
      $log_dir = $override_options['LogSettings']['FileLocation']
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
  -> class { '::mattermost::install': }
  -> class { '::mattermost::config': }
  ~> class { '::mattermost::service': }
  -> anchor { 'mattermost::end': }
}
