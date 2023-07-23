class graylog::server(
  $package_version = $graylog::params::package_version,
  Optional[Hash] $config = undef,
  $user = $graylog::params::server_user,
  $group = $graylog::params::server_group,
  $ensure = running,
  $enable = true,
) inherits graylog::params {
  if $config == undef {
    fail('Missing "config" setting!')
  }

  # Check mandatory settings
  if !('password_secret' in $config) {
    fail('Missing "password_secret" config setting!')
  }
  if ('root_password_sha2' in $config) {
    if length($config['root_password_sha2']) < 64 {
      fail('The root_password_sha2 parameter does not look like a SHA256 checksum!')
    }
  } else {
    fail('Missing "root_password_sha2" config setting!')
  }

  $data = $::graylog::params::default_config + $config

  anchor { 'graylog::server::start': }
  anchor { 'graylog::server::end': }

  package { 'graylog-server':
    ensure => $package_version
  }

  file { '/etc/graylog/server/server.conf':
    ensure  => file,
    owner   => $user,
    group   => $group,
    mode    => '0640',
    content => template("${module_name}/server/graylog.conf.erb"),
  }

  service { 'graylog-server':
    ensure     => $ensure,
    enable     => $enable,
    hasstatus  => true,
    hasrestart => true,
  }

  Anchor['graylog::server::start']
  ->Package['graylog-server']
  ->File['/etc/graylog/server/server.conf']
  ~>Service['graylog-server']
  ->Anchor['graylog::server::end']
}
