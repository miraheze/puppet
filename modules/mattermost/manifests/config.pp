# See README.md.
class mattermost::config inherits mattermost {
  $override_options = $mattermost::override_options
  $conf = $mattermost::conf
  $purge_conf = $mattermost::purge_conf
  $override_env_options = $mattermost::override_env_options
  $env_conf = $mattermost::env_conf
  $purge_env_conf = $mattermost::purge_env_conf
  $dir = regsubst(
    $mattermost::dir,
    '__VERSION__',
    $mattermost::version
  )
  $source_conf = "${dir}/config/config.json"
  if $purge_conf {
    file { $conf:
      content => '{}',
      owner   => $mattermost::user,
      group   => $mattermost::group,
      mode    => '0640',
      replace => true,
    }
  } else {
    if $mattermost::install_from_pkg {
      file { $conf:
        replace => false,
      }
    } else {
      file { $conf:
        source  => $source_conf,
        owner   => $mattermost::user,
        group   => $mattermost::group,
        mode    => '0640',
        replace => false,
      }
    }
  }
  mattermost_settings{ $conf:
    values  => $override_options,
    require => File[$conf],
  }
  if $mattermost::install_from_pkg {
    file { $env_conf:
      replace => false,
    }
  } else {
    file { $env_conf:
      ensure  => file,
      content => '',
      owner   => $mattermost::user,
      group   => $mattermost::group,
      mode    => '0640',
      replace => false,
    }
  }
  augeas{ $env_conf:
    changes => template('mattermost/env.augeas.erb'),
    lens    => 'Shellvars.lns',
    incl    => $env_conf,
    require => File[$env_conf],
  }
}
