# See README.md.
class mattermost::service inherits mattermost {
  $provider = $mattermost::service_provider ? {
    ''      => undef,
    default => $mattermost::service_provider,
  }
  if $mattermost::install_from_pkg and $mattermost::manage_service {
    service { $mattermost::service_name:
      ensure    => 'running',
      enable    => true,
      provider  => $provider,
      subscribe => Package[$mattermost::pkg],
    }
  }
  elsif $mattermost::install_service and $mattermost::manage_service {
    service { $mattermost::service_name:
      ensure    => 'running',
      enable    => true,
      provider  => $provider,
      subscribe => File[$mattermost::symlink],
    }
  }
}
