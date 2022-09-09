class { '::icinga::repos':
  manage_epel => true,
}

class { '::icinga::server':
  ca                   => true,
  config_server        => true,
  colocation_endpoints => { 'debian10.localdomain' => { 'host' => '192.168.5.23', } },
  workers              => { 'dmz' => { 'endpoints' => { 'debian9.localdomain' => { 'host' => '192.168.5.22' }}, }},
  global_zones         => [ 'global-templates', 'linux-commands', 'windows-commands' ],
  logging_type         => 'syslog',
  logging_level        => 'warning',
}
